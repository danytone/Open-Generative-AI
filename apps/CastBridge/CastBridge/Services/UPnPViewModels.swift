import Foundation
import Combine

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
    }

    func discover() {
        cancelDiscovery()

        discoverTask = Task {
            isDiscovering = true
            statusMessage = "Ricerca server in corso…"
            defer {
                isDiscovering = false
                discoverTask = nil
            }

            let existing = servers

            do {
                try Task.checkCancellation()
                let locations = try await ssdpClient.discover(timeout: 4) {
                    Task.isCancelled
                }
                try Task.checkCancellation()

                var foundServers: [UPnPMediaServer] = []
                var seenIDs = Set(existing.map(\.id))

                await withTaskGroup(of: UPnPMediaServer?.self) { group in
                    for location in locations {
                        group.addTask {
                            await self.fetchServer(at: location)
                        }
                    }

                    for await server in group {
                        try? Task.checkCancellation()
                        guard let server, !seenIDs.contains(server.id) else { continue }
                        seenIDs.insert(server.id)
                        foundServers.append(server)
                    }
                }

                if foundServers.isEmpty {
                    servers = existing
                    statusMessage = existing.isEmpty
                        ? "Nessun server trovato. Aggiungi l'URL del router qui sotto."
                        : "Nessun nuovo server trovato. Usa quelli già in lista."
                } else {
                    servers = (existing + foundServers).sorted {
                        $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending
                    }
                    statusMessage = "Trovati \(foundServers.count) server."
                }
            } catch is CancellationError {
                statusMessage = "Ricerca interrotta."
            } catch {
                servers = existing
                statusMessage = existing.isEmpty
                    ? "Ricerca fallita. Aggiungi il server manualmente qui sotto."
                    : "Ricerca fallita. I server in lista restano disponibili."
            }
        }
    }

    func cancelDiscovery() {
        discoverTask?.cancel()
        discoverTask = nil
        isDiscovering = false
    }

    func addManualServer() async {
        let trimmed = manualServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            statusMessage = "URL non valido. Esempio: http://192.168.1.1"
            return
        }

        cancelDiscovery()
        isAddingManual = true
        statusMessage = "Connessione al server…"
        defer { isAddingManual = false }

        if let server = await fetchServer(at: url) {
            if !servers.contains(where: { $0.id == server.id }) {
                servers.append(server)
                servers.sort { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
            }
            manualServerURL = ""
            statusMessage = "Server \"\(server.friendlyName)\" aggiunto."
        } else {
            statusMessage = "Impossibile connettersi. Verifica URL e rete Wi‑Fi."
        }
    }

    private func fetchServer(at location: URL) async -> UPnPMediaServer? {
        do {
            var request = URLRequest(url: location)
            request.timeoutInterval = 8
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try UPnPDeviceParser.parseDeviceDescription(data: data, locationURL: location)
        } catch {
            return nil
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
