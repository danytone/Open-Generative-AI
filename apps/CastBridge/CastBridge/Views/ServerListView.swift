import SwiftUI

struct ServerListView: View {
  @StateObject private var viewModel = UPnPDiscoveryViewModel()
  @EnvironmentObject private var castManager: CastManager

  var body: some View {
    NavigationStack {
      List {
        addServerSection
        serversSection
      }
      .navigationTitle("CastBridge")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          CastToolbarButton()
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

  private var addServerSection: some View {
    Section {
      HStack {
        TextField("Es. 192.168.1.1 oppure http://nas.local:8200", text: $viewModel.manualServerURL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.URL)

        if !viewModel.manualServerURL.isEmpty {
          Button {
            viewModel.manualServerURL = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }

      Button {
        Task { await viewModel.addManualServer() }
      } label: {
        if viewModel.isAddingManual {
          HStack {
            ProgressView()
            Text("Connessione…")
          }
        } else {
          Label("Aggiungi server", systemImage: "plus.circle.fill")
        }
      }
      .disabled(
        viewModel.manualServerURL.trimmingCharacters(in: .whitespaces).isEmpty
          || viewModel.isAddingManual
      )

      if viewModel.isDiscovering {
        HStack {
          ProgressView()
          Text("Ricerca automatica in corso…")
            .foregroundStyle(.secondary)
          Spacer()
          Button("Interrompi", role: .cancel) {
            viewModel.cancelDiscovery()
          }
        }
      } else {
        Button {
          viewModel.discover()
        } label: {
          Label("Cerca automaticamente", systemImage: "wifi")
        }
      }

      if let status = viewModel.statusMessage {
        Text(status)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } header: {
      Text("Aggiungi o cerca un server")
    } footer: {
      Text("Se la ricerca automatica non trova nulla (comune con Wi‑Fi mesh), scrivi l'IP del router o del NAS e tocca Aggiungi server. Trovi l'IP in Impostazioni → Wi‑Fi → (i) → Router.")
    }
  }

  private var serversSection: some View {
    Section {
      if viewModel.servers.isEmpty {
        Text("Nessun server in lista.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.servers) { server in
          NavigationLink(value: server) {
            ServerRowView(server: server)
          }
          .swipeActions {
            Button(role: .destructive) {
              viewModel.removeServer(server)
            } label: {
              Label("Rimuovi", systemImage: "trash")
            }
          }
        }
      }
    } header: {
      Text("Server disponibili")
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
