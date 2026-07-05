import Foundation
import Combine

#if canImport(GoogleCast)
import GoogleCast
#endif

@MainActor
final class CastManager: NSObject, ObservableObject {
    static let shared = CastManager()

    @Published private(set) var isConnected = false
    @Published private(set) var deviceName: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentMediaTitle: String?
    @Published private(set) var discoveredDeviceCount = 0
    @Published var lastError: String?

    #if canImport(GoogleCast)
    private var sessionManager: GCKSessionManager?
    private var discoveryManager: GCKDiscoveryManager?
    #endif

    private override init() {
        super.init()
    }

    func configure() {
        #if canImport(GoogleCast)
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        options.disableDiscoveryAutostart = false
        options.startDiscoveryAfterFirstTapOnCastButton = false
        GCKCastContext.setSharedInstanceWith(options)

        sessionManager = GCKCastContext.sharedInstance().sessionManager
        sessionManager?.add(self)

        discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        discoveryManager?.add(self)
        discoveryManager?.startDiscovery()
        #endif
    }

    /// Forces a fresh Chromecast scan. Useful after the app returns from
    /// background, after granting the Local Network permission, or when
    /// the standard button doesn't pick up devices right away.
    func restartDiscovery() {
        #if canImport(GoogleCast)
        discoveryManager?.stopDiscovery()
        discoveryManager?.startDiscovery()
        lastError = nil
        #else
        lastError = "Google Cast SDK non installato. Esegui 'pod install' e ricompila il progetto."
        #endif
    }

    func castMedia(url: URL, title: String, mimeType: String?, subtitle: String? = nil) {
        lastError = nil
        currentMediaTitle = title

        #if canImport(GoogleCast)
        guard let session = sessionManager?.currentCastSession else {
            lastError = "Nessun Chromecast connesso. Tocca il pulsante Cast per selezionare un dispositivo."
            return
        }

        let resolvedMime = mimeType ?? mimeTypeForURL(url)
        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.streamType = GCKMediaStreamType.buffered
        builder.contentType = resolvedMime
        builder.metadata = createMetadata(title: title, subtitle: subtitle)
        builder.streamDuration = 0

        let request = session.remoteMediaClient?.loadMedia(builder.build())
        request?.delegate = self
        #else
        lastError = "Google Cast SDK non installato. Esegui 'pod install' e ricompila il progetto."
        #endif
    }

    func play() {
        #if canImport(GoogleCast)
        _ = sessionManager?.currentCastSession?.remoteMediaClient?.play()
        #endif
    }

    func pause() {
        #if canImport(GoogleCast)
        _ = sessionManager?.currentCastSession?.remoteMediaClient?.pause()
        #endif
    }

    func stop() {
        #if canImport(GoogleCast)
        _ = sessionManager?.currentCastSession?.remoteMediaClient?.stop()
        currentMediaTitle = nil
        isPlaying = false
        #endif
    }

    private func mimeTypeForURL(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m3u8":
            return "application/vnd.apple.mpegurl"
        case "mp4", "m4v":
            return "video/mp4"
        case "webm":
            return "video/webm"
        case "mkv":
            return "video/x-matroska"
        case "avi":
            return "video/x-msvideo"
        case "mov":
            return "video/quicktime"
        case "ts":
            return "video/mp2t"
        default:
            return "video/mp4"
        }
    }

    #if canImport(GoogleCast)
    private func createMetadata(title: String, subtitle: String?) -> GCKMediaMetadata {
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        if let subtitle {
            metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle)
        }
        return metadata
    }
    #endif
}

#if canImport(GoogleCast)
extension CastManager: GCKSessionManagerListener {
    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        Task { @MainActor in
            isConnected = true
            deviceName = session.device.friendlyName
        }
    }

    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        Task { @MainActor in
            isConnected = false
            deviceName = nil
            isPlaying = false
            if let error {
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated func sessionManager(_ sessionManager: GCKSessionManager, didResumeSession session: GCKSession) {
        Task { @MainActor in
            isConnected = true
            deviceName = session.device.friendlyName
        }
    }
}

extension CastManager: GCKRequestDelegate {
    nonisolated func requestDidComplete(_ request: GCKRequest) {
        Task { @MainActor in
            isPlaying = true
        }
    }

    nonisolated func request(_ request: GCKRequest, didFailWithError error: GCKError) {
        Task { @MainActor in
            lastError = error.localizedDescription
            isPlaying = false
        }
    }
}

extension CastManager: GCKDiscoveryManagerListener {
    nonisolated func didUpdateDeviceList() {
        Task { @MainActor in
            discoveredDeviceCount = GCKCastContext.sharedInstance().discoveryManager.deviceCount
        }
    }
}
#endif
