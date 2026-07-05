import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnWiFi = false
    @Published private(set) var localIPAddress: String?

    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var lastPathSignature: String?

    var onNetworkChanged: (() -> Void)?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.castbridge.network-monitor"))
    }

    private func handlePathUpdate(_ path: NWPath) {
        let signature = "\(path.status)-\(path.availableInterfaces.map(\.name).joined(separator: ","))"
        let changed = signature != lastPathSignature
        lastPathSignature = signature

        isOnWiFi = path.status == .satisfied
        localIPAddress = Self.wifiIPv4Address()

        if changed {
            onNetworkChanged?()
        }
    }

    private static func wifiIPv4Address() -> String? {
        var address: String?
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else { return nil }
        defer { freeifaddrs(ifaddrPointer) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }

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
