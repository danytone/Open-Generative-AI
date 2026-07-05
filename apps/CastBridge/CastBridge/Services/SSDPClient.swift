import Foundation
import Network

final class SSDPClient: @unchecked Sendable {
    static let multicastHost = "239.255.255.250"
    static let multicastPort: UInt16 = 1900

    private let searchTargets = [
        "upnp:rootdevice",
        "urn:schemas-upnp-org:device:MediaServer:1"
    ]

    func discover(timeout: TimeInterval = 5) async throws -> [URL] {
        try await withCheckedThrowingContinuation { continuation in
            let session = DiscoverySession()

            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(SSDPClient.multicastHost),
                port: NWEndpoint.Port(integerLiteral: SSDPClient.multicastPort)
            )

            guard let multicastGroup = try? NWMulticastGroup(for: [endpoint]) else {
                continuation.resume(throwing: UPnPError.discoveryFailed("Impossibile creare gruppo multicast"))
                return
            }

            let group = NWConnectionGroup(with: multicastGroup, using: .udp)

            group.setReceiveHandler(maximumMessageSize: 65_536, rejectOversizedMessages: true) { _, content, _ in
                guard let content,
                      let response = String(data: content, encoding: .utf8),
                      let location = self.parseLocation(from: response) else {
                    return
                }
                session.addLocation(location)
            }

            group.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    for target in self.searchTargets {
                        self.sendMSearch(on: group, searchTarget: target)
                    }
                case .failed(let error):
                    guard session.markResumed() else { return }
                    group.cancel()
                    continuation.resume(throwing: UPnPError.discoveryFailed(error.localizedDescription))
                default:
                    break
                }
            }

            group.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard session.markResumed() else { return }
                group.cancel()
                continuation.resume(returning: session.locations())
            }
        }
    }

    private func sendMSearch(on group: NWConnectionGroup, searchTarget: String) {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(SSDPClient.multicastHost):\(SSDPClient.multicastPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(searchTarget)\r
        USER-AGENT: CastBridge/1.0 UPnP/1.1\r
        \r

        """
        guard let data = message.data(using: .utf8) else { return }
        group.send(content: data) { _ in }
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

private final class DiscoverySession: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private var discoveredLocations = Set<URL>()

    func addLocation(_ location: URL) {
        lock.lock()
        discoveredLocations.insert(location)
        lock.unlock()
    }

    func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }

    func locations() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return Array(discoveredLocations)
    }
}
