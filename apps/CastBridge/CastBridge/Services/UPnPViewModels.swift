import Foundation
import Combine

private enum ServerStore {
    private static let key = "castbridge.savedServers"

    static func load() -> [UPnPMediaServer] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let servers = try? JSONDecoder().decode([UPnPMediaServer].self, from: data) else {
            return []
        }
        return servers
    }

    static func save(_ servers: [UPnPMediaServer]) {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
final class UPnPDiscoveryViewModel: ObservableObject {
    @Published private(set) var servers: [UPnPMediaServer] = []
    @Published private(set) var isDiscovering = false
    @Published private(set) var isAddingManual = false
    @Published var statusMessage: String?
    @Published var manualServerURL = ""

    private let ssdpClient = SSDPClient()
    private let session: URLSession
    private var discoverTask: Task<Void, Never>?

    init(session: URLSession = .shared) {
        self.session = session
        servers = ServerStore.load()
        if !servers.isEmpty {
            statusMessage = "\(servers.count) server salvati da sessioni precedenti."
        }
    }

    func discover() {
        discoverTask?.cancel()

        discoverTask = Task { [weak self] in
            guard let self else { return }

            self.isDiscovering = true
            self.statusMessage = "Ricerca in corso sulla rete locale…"
            defer {
                self.isDiscovering = false
                self.discoverTask = nil
            }

            let existing = self.servers
            let locations = await self.ssdpClient.discover(timeout: 6)

            guard !Task.isCancelled else {
                self.statusMessage = "Ricerca interrotta."
                return
            }

            var foundServers: [UPnPMediaServer] = []
            var seenIDs = Set(existing.map(\.id))

            await withTaskGroup(of: UPnPMediaServer?.self) { group in
                for location in locations {
                    group.addTask {
                        await self.fetchServer(at: location)
                    }
                }
                for await server in group {
                    guard let server, !seenIDs.contains(server.id) else { continue }
                    seenIDs.insert(server.id)
                    foundServers.append(server)
                }
            }

            guard !Task.isCancelled else {
                self.statusMessage = "Ricerca interrotta."
                return
            }

            if foundServers.isEmpty {
                self.servers = existing
                self.statusMessage = existing.isEmpty
                    ? "Nessun server trovato via ricerca automatica. Aggiungi l'IP manualmente qui sotto."
                    : "Nessun nuovo server trovato. Restano disponibili quelli già in lista."
            } else {
                self.servers = (existing + foundServers).sorted {
                    $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending
                }
                ServerStore.save(self.servers)
                self.statusMessage = "Trovati \(foundServers.count) server."
            }
        }
    }

    func cancelDiscovery() {
        discoverTask?.cancel()
        discoverTask = nil
        isDiscovering = false
    }

    func removeServer(_ server: UPnPMediaServer) {
        servers.removeAll { $0.id == server.id }
        ServerStore.save(servers)
    }

    func addManualServer() async {
        let trimmed = manualServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Scrivi l'IP o l'URL del server nel campo sopra."
            return
        }

        isAddingManual = true
        statusMessage = "Connessione in corso…"
        defer { isAddingManual = false }

        let candidates = Self.candidateURLs(from: trimmed)

        let found: UPnPMediaServer? = await withTaskGroup(of: UPnPMediaServer?.self) { group in
            for url in candidates {
                group.addTask {
                    await self.fetchServer(at: url)
                }
            }
            for await server in group {
                if let server {
                    group.cancelAll()
                    return server
                }
            }
            return nil
        }

        if let server = found {
            if !servers.contains(where: { $0.id == server.id }) {
                servers.append(server)
                servers.sort { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
            }
            ServerStore.save(servers)
            manualServerURL = ""
            statusMessage = "Server \"\(server.friendlyName)\" aggiunto."
        } else {
            statusMessage = """
            Nessun servizio media server trovato a questo indirizzo. \
            Verifica che la condivisione DLNA/USB sia attiva sul router, \
            oppure prova con l'IP del NAS/PC che condivide i file.
            """
        }
    }

    private func fetchServer(at location: URL) async -> UPnPMediaServer? {
        do {
            var request = URLRequest(url: location)
            request.timeoutInterval = 4
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try UPnPDeviceParser.parseDeviceDescription(data: data, locationURL: location)
        } catch {
            return nil
        }
    }

    private static func candidateURLs(from input: String) -> [URL] {
        var normalized = input
        if !normalized.contains("://") {
            normalized = "http://\(normalized)"
        }
        guard let base = URL(string: normalized), let host = base.host else { return [] }

        var candidates: [URL] = [base]

        let paths = [
            "/rootDesc.xml",
            "/description.xml",
            "/DeviceDescription.xml",
            "/upnp/DeviceDesc.xml",
            "/dmr/description.xml",
            "/MediaServer/DeviceDesc.xml",
            "/ctl/desc.xml",
            "/igd.xml",
            "/upnp/desc/aios_device/aios_device.xml"
        ]

        var ports: Set<Int> = [8200, 49152, 49153, 8080, 2869, 5000]
        if let explicitPort = base.port {
            ports.insert(explicitPort)
        } else {
            ports.insert(80)
        }

        for port in ports {
            for path in paths {
                var components = URLComponents()
                components.scheme = "http"
                components.host = host
                components.port = port == 80 ? nil : port
                components.path = path
                if let url = components.url {
                    candidates.append(url)
                }
            }
        }

        var seen = Set<String>()
        return candidates.filter { url in
            let key = url.absoluteString
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

@MainActor
final class MediaBrowserViewModel: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var breadcrumbs: [MediaBreadcrumb] = []

    private let server: UPnPMediaServer
    private let contentDirectory: ContentDirectoryService

    struct MediaBreadcrumb: Identifiable, Hashable {
        let id: String
        let title: String
    }

    init(server: UPnPMediaServer) {
        self.server = server
        self.contentDirectory = ContentDirectoryService(server: server)
        self.breadcrumbs = [MediaBreadcrumb(id: "0", title: server.friendlyName)]
    }

    func load(objectID: String = "0") async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await contentDirectory.browse(objectID: objectID)
            items = result.items.sorted { lhs, rhs in
                if lhs.isContainer != rhs.isContainer {
                    return lhs.isContainer
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }

    func openFolder(_ item: MediaItem) async {
        guard item.isContainer else { return }
        breadcrumbs.append(MediaBreadcrumb(id: item.id, title: item.title))
        await load(objectID: item.id)
    }

    func navigateToBreadcrumb(_ breadcrumb: MediaBreadcrumb) async {
        guard let index = breadcrumbs.firstIndex(of: breadcrumb) else { return }
        breadcrumbs = Array(breadcrumbs.prefix(through: index))
        await load(objectID: breadcrumb.id)
    }

    func goBack() async {
        guard breadcrumbs.count > 1 else { return }
        breadcrumbs.removeLast()
        if let current = breadcrumbs.last {
            await load(objectID: current.id)
        }
    }
}
