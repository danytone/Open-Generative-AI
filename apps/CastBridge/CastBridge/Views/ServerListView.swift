import SwiftUI

struct ServerListView: View {
  @StateObject private var viewModel = UPnPDiscoveryViewModel()
  @ObservedObject private var networkMonitor = NetworkMonitor.shared
  @EnvironmentObject private var castManager: CastManager
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.servers.isEmpty && !viewModel.isDiscovering {
          emptyState
        } else {
          serverList
        }
      }
      .navigationTitle("CastBridge")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          CastToolbarButton()
        }
        ToolbarItem(placement: .topBarLeading) {
          Button {
            Task { await viewModel.discover() }
          } label: {
            if viewModel.isDiscovering {
              ProgressView()
            } else {
              Image(systemName: "arrow.clockwise")
            }
          }
          .disabled(viewModel.isDiscovering)
        }
      }
      .safeAreaInset(edge: .bottom) {
        if castManager.isConnected {
          CastMiniController()
        }
      }
      .task {
        NetworkMonitor.shared.onNetworkChanged = {
          Task { await viewModel.discover() }
        }
        await viewModel.discover()
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active {
          Task { await viewModel.discover() }
        }
      }
      .alert("Errore", isPresented: .constant(viewModel.errorMessage != nil)) {
        Button("OK") { viewModel.errorMessage = nil }
      } message: {
        Text(viewModel.errorMessage ?? "")
      }
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("Nessun server", systemImage: "wifi.slash")
    } description: {
      Text(emptyStateMessage)
    } actions: {
      Button("Cerca server") {
        Task { await viewModel.discover(keepCachedOnFailure: false) }
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private var emptyStateMessage: String {
    var parts = [
      "iPhone, router Vodafone e Chromecast devono essere sulla stessa rete Wi‑Fi.",
      "La ricerca automatica usa multicast: su alcuni router Vodafone non funziona da tutte le stanze.",
      "Aggiungi manualmente l'IP del router (es. http://192.168.1.1)."
    ]
    if let ip = networkMonitor.localIPAddress {
      parts.append("Il tuo iPhone è su \(ip).")
    }
    return parts.joined(separator: " ")
  }

  private var serverList: some View {
    List {
      if let ip = networkMonitor.localIPAddress {
        Section {
          Text("Rete iPhone: \(ip)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section {
        HStack {
          TextField("URL server manuale", text: $viewModel.manualServerURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
          Button("Aggiungi") {
            Task { await viewModel.addManualServer() }
          }
          .disabled(viewModel.manualServerURL.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      } header: {
        Text("Server manuale")
      } footer: {
        Text("Se la chiavetta Vodafone sparisce dopo il Cast, aggiungi qui l'URL del router. Lo trovi nell'app Vodafone Station o in Impostazioni Wi‑Fi → (i) sulla rete.")
      }

      Section("Server trovati") {
        ForEach(viewModel.servers) { server in
          NavigationLink(value: server) {
            ServerRowView(server: server)
          }
        }
      }
    }
    .navigationDestination(for: UPnPMediaServer.self) { server in
      MediaBrowserView(server: server)
    }
    .overlay {
      if viewModel.isDiscovering && viewModel.servers.isEmpty {
        ProgressView("Ricerca server UPnP...")
      }
    }
  }
}

struct ServerRowView: View {
  let server: UPnPMediaServer

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(server.friendlyName)
        .font(.headline)
      HStack(spacing: 8) {
        if let manufacturer = server.manufacturer {
          Text(manufacturer)
        }
        if let model = server.modelName {
          Text("· \(model)")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      Text(server.locationURL.host ?? server.locationURL.absoluteString)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  ServerListView()
    .environmentObject(CastManager.shared)
}
