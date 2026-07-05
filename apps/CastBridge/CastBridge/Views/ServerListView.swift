import SwiftUI

struct ServerListView: View {
  @StateObject private var viewModel = UPnPDiscoveryViewModel()
  @EnvironmentObject private var castManager: CastManager

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack {
            TextField("http://192.168.1.1", text: $viewModel.manualServerURL)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .keyboardType(.URL)
            Button("Aggiungi") {
              Task { await viewModel.addManualServer() }
            }
            .disabled(
              viewModel.manualServerURL.trimmingCharacters(in: .whitespaces).isEmpty
                || viewModel.isAddingManual
            )
          }

          if viewModel.isDiscovering {
            HStack {
              ProgressView()
              Text("Ricerca automatica in corso…")
                .foregroundStyle(.secondary)
              Spacer()
              Button("Stop") {
                viewModel.cancelDiscovery()
              }
              .buttonStyle(.bordered)
            }
          }

          if let status = viewModel.statusMessage {
            Text(status)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("Aggiungi server")
        } footer: {
          Text("Puoi aggiungere il router anche durante la ricerca. Trova l'IP in Impostazioni → Wi‑Fi → (i) → Router.")
        }

        Section {
          if viewModel.servers.isEmpty {
            Text("Nessun server in lista.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(viewModel.servers) { server in
              NavigationLink(value: server) {
                ServerRowView(server: server)
              }
            }
          }
        } header: {
          HStack {
            Text("Server disponibili")
            Spacer()
            if !viewModel.isDiscovering {
              Button("Cerca") {
                viewModel.discover()
              }
              .font(.caption)
            }
          }
        }
      }
      .navigationTitle("CastBridge")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          CastToolbarButton()
        }
        ToolbarItem(placement: .topBarLeading) {
          if viewModel.isDiscovering {
            Button("Stop") {
              viewModel.cancelDiscovery()
            }
          } else {
            Button {
              viewModel.discover()
            } label: {
              Image(systemName: "arrow.clockwise")
            }
          }
        }
      }
      .navigationDestination(for: UPnPMediaServer.self) { server in
        MediaBrowserView(server: server)
      }
      .safeAreaInset(edge: .bottom) {
        if castManager.isConnected {
          CastMiniController()
        }
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
