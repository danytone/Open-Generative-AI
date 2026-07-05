import SwiftUI

struct ServerListView: View {
  @StateObject private var viewModel = UPnPDiscoveryViewModel()
  @EnvironmentObject private var castManager: CastManager

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
        await viewModel.discover()
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
      Text("Assicurati che iPhone e server UPnP/DLNA siano sulla stessa rete Wi‑Fi, poi tocca Aggiorna.")
    } actions: {
      Button("Cerca server") {
        Task { await viewModel.discover() }
      }
      .buttonStyle(.borderedProminent)
    }
  }

  private var serverList: some View {
    List {
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
        Text("Utile per Jellyfin, Plex DLNA, MiniDLNA o server personalizzati.")
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
