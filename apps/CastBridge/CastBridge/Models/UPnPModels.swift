import Foundation

struct UPnPMediaServer: Identifiable, Hashable, Codable {
    let id: String
    let friendlyName: String
    let manufacturer: String?
    let modelName: String?
    let locationURL: URL
    var controlURL: URL?
    var eventSubURL: URL?
    var scpdURL: URL?
    var discoveredAt: Date

    init(
        id: String,
        friendlyName: String,
        manufacturer: String? = nil,
        modelName: String? = nil,
        locationURL: URL,
        controlURL: URL? = nil,
        eventSubURL: URL? = nil,
        scpdURL: URL? = nil,
        discoveredAt: Date = Date()
    ) {
        self.id = id
        self.friendlyName = friendlyName
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.locationURL = locationURL
        self.controlURL = controlURL
        self.eventSubURL = eventSubURL
        self.scpdURL = scpdURL
        self.discoveredAt = discoveredAt
    }
}

struct MediaItem: Identifiable, Hashable {
    let id: String
    let title: String
    let isContainer: Bool
    let parentID: String
    let mediaClass: String?
    let streamURL: URL?
    let mimeType: String?
    let duration: TimeInterval?
    let size: Int64?
    let thumbnailURL: URL?

    var isVideo: Bool {
        guard !isContainer else { return false }
        if let mimeType, mimeType.hasPrefix("video/") { return true }
        if let mediaClass, mediaClass.contains("videoItem") { return true }
        if let streamURL {
            let ext = streamURL.pathExtension.lowercased()
            return ["mp4", "mkv", "avi", "mov", "m4v", "webm", "ts", "m3u8"].contains(ext)
        }
        return false
    }

    var formattedDuration: String? {
        guard let duration, duration > 0 else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedSize: String? {
        guard let size, size > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct BrowseResult {
    let items: [MediaItem]
    let totalMatches: Int
}

enum UPnPError: LocalizedError {
    case discoveryFailed(String)
    case invalidResponse
    case serviceNotFound
    case browseFailed(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .discoveryFailed(let message):
            return "Discovery fallita: \(message)"
        case .invalidResponse:
            return "Risposta UPnP non valida"
        case .serviceNotFound:
            return "Servizio ContentDirectory non trovato"
        case .browseFailed(let message):
            return "Browsing fallito: \(message)"
        case .invalidURL:
            return "URL non valido"
        }
    }
}
