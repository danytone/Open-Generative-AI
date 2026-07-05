import SwiftUI

struct MediaBrowserView: View {
  let server: UPnPMediaServer

  @StateObject private var viewModel: MediaBrowserViewModel
  @EnvironmentObject private var castManager: CastManager
  @State private var showCastError = false

  init(server: UPnPMediaServer) {
    self.server = server
    _viewModel = StateObject(wrappedValue: MediaBrowserViewModel(server: server))
  }

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.items.isEmpty {
        ProgressView("Caricamento contenuti...")
      } else if viewModel.items.isEmpty {
        ContentUnavailableView(
          "Cartella vuota",
          systemImage: "folder",
          description: Text("Nessun file multimediale in questa cartella.")
        )
      } else {
        mediaList
      }
    }
    .navigationTitle(server.friendlyName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        CastToolbarButton()
      }
    }
    .safeAreaInset(edge: .bottom) {
      if castManager.isConnected {
        CastMiniController()
      }
    }
    .task {
      await viewModel.load()
    }
    .alert("Errore", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") { viewModel.errorMessage = nil }
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
    .onChange(of: castManager.lastError) { _, newValue in
      showCastError = newValue != nil
    }
    .alert("Cast", isPresented: $showCastError) {
      Button("OK") {
        castManager.lastError = nil
        showCastError = false
      }
    } message: {
      Text(castManager.lastError ?? "")
    }
  }

  private var mediaList: some View {
    List {
      if viewModel.breadcrumbs.count > 1 {
        Section {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
              ForEach(viewModel.breadcrumbs) { crumb in
                Button {
                  Task { await viewModel.navigateToBreadcrumb(crumb) }
                } label: {
                  Text(crumb.title)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)

                if crumb.id != viewModel.breadcrumbs.last?.id {
                  Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }

      Section {
        ForEach(viewModel.items) { item in
          MediaRowView(item: item) {
            handleSelection(item)
          }
        }
      }
    }
    .refreshable {
      if let current = viewModel.breadcrumbs.last {
        await viewModel.load(objectID: current.id)
      }
    }
  }

  private func handleSelection(_ item: MediaItem) {
    if item.isContainer {
      Task { await viewModel.openFolder(item) }
      return
    }

    guard let url = item.streamURL else {
      castManager.lastError = "URL di streaming non disponibile per questo file."
      showCastError = true
      return
    }

    castManager.castMedia(
      url: url,
      title: item.title,
      mimeType: item.mimeType,
      subtitle: server.friendlyName
    )
  }
}

struct MediaRowView: View {
  let item: MediaItem
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Image(systemName: item.isContainer ? "folder.fill" : "play.rectangle.fill")
          .font(.title2)
          .foregroundStyle(item.isContainer ? .yellow : .accentColor)
          .frame(width: 36)

        VStack(alignment: .leading, spacing: 4) {
          Text(item.title)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(2)

          HStack(spacing: 8) {
            if let duration = item.formattedDuration {
              Label(duration, systemImage: "clock")
            }
            if let size = item.formattedSize {
              Label(size, systemImage: "doc")
            }
            if item.isVideo {
              Text("Video")
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15), in: Capsule())
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        Spacer()

        if item.isContainer {
          Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
        } else {
          Image(systemName: "airplayvideo")
            .foregroundStyle(.accentColor)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    MediaBrowserView(
      server: UPnPMediaServer(
        id: "test",
        friendlyName: "NAS Media",
        locationURL: URL(string: "http://192.168.1.10:8200")!
      )
    )
  }
  .environmentObject(CastManager.shared)
}
