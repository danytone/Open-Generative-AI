import SwiftUI

struct ContentView: View {
  var body: some View {
    TabView {
      ServerListView()
        .tabItem {
          Label("Server", systemImage: "server.rack")
        }

      ManualStreamView()
        .tabItem {
          Label("URL diretto", systemImage: "link")
        }

      CastStatusView()
        .tabItem {
          Label("Cast", systemImage: "tv")
        }
    }
    .tint(.accentColor)
  }
}

#Preview {
  ContentView()
    .environmentObject(CastManager.shared)
}
