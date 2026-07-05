import Foundation
import Darwin

actor SSDPClient {
    static let multicastHost = "239.255.255.250"
    static let multicastPort: UInt16 = 1900

    private let searchTargets = [
        "upnp:rootdevice",
        "urn:schemas-upnp-org:device:MediaServer:1"
    ]

    func discover(timeout: TimeInterval = 5) async throws -> [URL] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let locations = try self.discoverUsingSocket(timeout: timeout)
                    continuation.resume(returning: locations)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func discoverUsingSocket(timeout: TimeInterval) throws -> [URL] {
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw UPnPError.discoveryFailed("Impossibile aprire socket UDP")
        }
        defer { close(socketFD) }

        var reuse: Int32 = 1
        setsockopt(
            socketFD,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var bindAddress = sockaddr_in()
        bindAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddress.sin_family = sa_family_t(AF_INET)
        bindAddress.sin_port = 0
        bindAddress.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &bindAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw UPnPError.discoveryFailed("Impossibile collegarsi alla rete locale")
        }

        for target in searchTargets {
            try sendMSearch(socketFD: socketFD, searchTarget: target)
        }

        return try collectResponses(socketFD: socketFD, timeout: timeout)
    }

    private func sendMSearch(socketFD: Int32, searchTarget: String) throws {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(Self.multicastHost):\(Self.multicastPort)\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: \(searchTarget)\r
        USER-AGENT: CastBridge/1.0 UPnP/1.1\r
        \r

        """

        guard let data = message.data(using: .utf8) else { return }

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = Self.multicastPort.bigEndian
        inet_pton(AF_INET, Self.multicastHost, &destination.sin_addr)

        let sent = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &destination) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    sendto(
                        socketFD,
                        buffer.baseAddress,
                        data.count,
                        0,
                        address,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }

        guard sent > 0 else {
            throw UPnPError.discoveryFailed("Invio M-SEARCH fallito")
        }
    }

    private func collectResponses(socketFD: Int32, timeout: TimeInterval) throws -> [URL] {
        var flags = fcntl(socketFD, F_GETFL, 0)
        _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)

        var locations = Set<URL>()
        let deadline = Date().addingTimeInterval(timeout)
        var buffer = [UInt8](repeating: 0, count: 65_536)

        while Date() < deadline {
            var source = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)

            let received = withUnsafeMutablePointer(to: &source) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    recvfrom(
                        socketFD,
                        &buffer,
                        buffer.count,
                        0,
                        address,
                        &sourceLength
                    )
                }
            }

            if received > 0,
               let response = String(bytes: buffer.prefix(received), encoding: .utf8),
               let location = parseLocation(from: response) {
                locations.insert(location)
            }

            usleep(100_000)
        }

        return Array(locations)
    }

    private func parseLocation(from response: String) -> URL? {
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
}
