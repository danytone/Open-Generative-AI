import SwiftUI

struct ServerListView: View {
  @StateObject private var viewModel = UPnPDiscoveryViewModel()
  @EnvironmentObject private var castManager: CastManager
  @FocusState private var urlFieldFocused: Bool

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 10) {
            Text("URL del server")
              .font(.caption)
              .foregroundStyle(.secondary)

            HStack {
              TextField("Incolla qui l'URL", text: $viewModel.manualServerURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($urlFieldFocused)

              if !viewModel.manualServerURL.isEmpty {
                Button {
                  viewModel.clearManualURL()
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
              }
            }

            HStack {
              Button {
                urlFieldFocused = true
              } label: {
                Label("Modifica URL", systemImage: "pencil")
              }
              .buttonStyle(.bordered)

              Spacer()

              Button {
                Task { await viewModel.addManualServer() }
              } label: {
                if viewModel.isAddingManual {
                  ProgressView()
                } else {
                  Text("Aggiungi")
                }
              }
              .buttonStyle(.borderedProminent)
              .disabled(viewModel.manualServerURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
          }
          .padding(.vertical, 4)

          if viewModel.isDiscovering {
            HStack {
              ProgressView()
              Text("Ricerca automatica…")
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
          Text("Il campo sopra è vuoto all'avvio: scrivi tu l'URL. Se hai già trovato il server Vodafone una volta, dovrebbe comparire in lista sotto.")
        }

        Section {
          if viewModel.servers.isEmpty {
            Text("Nessun server in lista. Usa “Cerca” o aggiungi l'URL manualmente.")
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
