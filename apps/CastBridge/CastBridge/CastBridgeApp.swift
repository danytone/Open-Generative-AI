import SwiftUI

@main
struct CastBridgeApp: App {
    @StateObject private var castManager = CastManager.shared

    init() {
        CastManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(castManager)
        }
    }
}
