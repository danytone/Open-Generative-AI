import Foundation

struct SSDPClient: Sendable {
    private static let multicastAddress = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900

    private static let searchTargets = [
        "ssdp:all",
        "upnp:rootdevice",
        "urn:schemas-upnp-org:device:MediaServer:1",
        "urn:schemas-upnp-org:service:ContentDirectory:1"
    ]

    /// Discovers UPnP device locations on the local network via SSDP M-SEARCH.
    /// Never throws: on any failure it simply returns an empty array so the
    /// caller can fall back to manually-added / cached servers.
    func discover(timeout: TimeInterval = 6) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            Self.performDiscovery(timeout: timeout)
        }.value
    }

    // MARK: - Socket-based discovery

    private static func performDiscovery(timeout: TimeInterval) -> [URL] {
        guard let socketFD = openSocket() else { return [] }
        defer { close(socketFD) }

        let deadline = Date().addingTimeInterval(timeout)
        var locations = Set<URL>()

        // Send the search burst a couple of times: Wi-Fi mesh networks and
        // busy 2.4GHz bands routinely drop the first UDP multicast packet.
        for _ in 0..<3 {
            for target in searchTargets {
                sendSearch(socketFD: socketFD, searchTarget: target)
            }
            usleep(200_000)
        }

        var buffer = [UInt8](repeating: 0, count: 65_536)

        while true {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }

            guard waitForReadableData(socketFD: socketFD, timeout: min(remaining, 0.5)) else {
                continue
            }

            var source = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)

            let received = withUnsafeMutablePointer(to: &source) { sourcePointer in
                sourcePointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                    recvfrom(socketFD, &buffer, buffer.count, 0, addr, &sourceLength)
                }
            }

            guard received > 0 else { continue }

            if let response = String(bytes: buffer.prefix(received), encoding: .utf8),
               let location = parseLocation(from: response) {
                locations.insert(location)
            }
        }

        return Array(locations)
    }

    private static func openSocket() -> Int32? {
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else { return nil }

        var reuseAddr: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        var reusePort: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEPORT, &reusePort, socklen_t(MemoryLayout<Int32>.size))

        // Higher TTL helps the M-SEARCH packet survive an extra hop on
        // Wi-Fi mesh systems (router <-> satellite) where default TTL 1
        // may be dropped before reaching the satellite's own segment.
        var ttl: Int32 = 4
        setsockopt(socketFD, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<Int32>.size))

        if let wifiAddress = wifiIPv4Address() {
            var interfaceAddr = in_addr()
            inet_pton(AF_INET, wifiAddress, &interfaceAddr)
            setsockopt(socketFD, IPPROTO_IP, IP_MULTICAST_IF, &interfaceAddr, socklen_t(MemoryLayout<in_addr>.size))
        }

        var bindAddress = sockaddr_in()
        bindAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddress.sin_family = sa_family_t(AF_INET)
        bindAddress.sin_port = 0
        bindAddress.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &bindAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                bind(socketFD, addr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(socketFD)
            return nil
        }

        var flags = fcntl(socketFD, F_GETFL, 0)
        flags |= O_NONBLOCK
        _ = fcntl(socketFD, F_SETFL, flags)

        return socketFD
    }

    private static func sendSearch(socketFD: Int32, searchTarget: String) {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(multicastAddress):\(multicastPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(searchTarget)\r
        USER-AGENT: CastBridge/1.0 UPnP/1.1\r
        \r

        """
        guard let data = message.data(using: .utf8) else { return }

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, multicastAddress, &destination.sin_addr)

        _ = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &destination) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                    sendto(socketFD, buffer.baseAddress, data.count, 0, addr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private static func waitForReadableData(socketFD: Int32, timeout: TimeInterval) -> Bool {
        var pollDescriptor = pollfd(fd: socketFD, events: Int16(POLLIN), revents: 0)
        let timeoutMs = Int32(max(0, timeout * 1000))
        let result = poll(&pollDescriptor, 1, timeoutMs)
        guard result > 0 else { return false }
        return (Int32(pollDescriptor.revents) & POLLIN) != 0
    }

    private static func parseLocation(from response: String) -> URL? {
        for line in response.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if key == "location" {
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return URL(string: value)
            }
        }
        return nil
    }

    static func wifiIPv4Address() -> String? {
        var address: String?
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else { return nil }
        defer { freeifaddrs(ifaddrPointer) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            address = String(cString: hostname)
            break
        }
        return address
    }
}
