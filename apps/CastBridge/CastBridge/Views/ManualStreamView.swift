import SwiftUI

struct ManualStreamView: View {
  @EnvironmentObject private var castManager: CastManager

  @State private var streamURL = ""
  @State private var title = ""
  @State private var mimeType = "video/mp4"
  @State private var showError = false

  private let mimeTypes = [
    "video/mp4",
    "application/vnd.apple.mpegurl",
    "video/webm",
    "video/x-matroska",
    "video/quicktime"
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("URL del video (http://...)", text: $streamURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)

          TextField("Titolo (opzionale)", text: $title)

          Picker("Tipo MIME", selection: $mimeType) {
            ForEach(mimeTypes, id: \.self) { type in
              Text(type).tag(type)
            }
          }
        } header: {
          Text("Stream diretto")
        } footer: {
          Text("Usa questa scheda per streammare un URL HTTP/HLS accessibile dalla rete locale, ad esempio da un server NAS o da un transcoder.")
        }

        Section {
          Button {
            castFromManualInput()
          } label: {
            Label("Invia a Chromecast", systemImage: "airplayvideo")
          }
          .disabled(!isValidURL)
        }

        Section("Esempi") {
          exampleButton(
            title: "HLS (.m3u8)",
            url: "http://192.168.1.10:8080/live/stream.m3u8",
            mime: "application/vnd.apple.mpegurl"
          )
          exampleButton(
            title: "MP4 locale",
            url: "http://192.168.1.10/videos/film.mp4",
            mime: "video/mp4"
          )
        }
      }
      .navigationTitle("URL diretto")
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
      .alert("Cast", isPresented: $showError) {
        Button("OK") {
          castManager.lastError = nil
          showError = false
        }
      } message: {
        Text(castManager.lastError ?? "URL non valido")
      }
    }
  }

  private var isValidURL: Bool {
    guard let url = URL(string: streamURL.trimmingCharacters(in: .whitespacesAndNewlines)),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https" else {
      return false
    }
    return true
  }

  private func castFromManualInput() {
    let trimmedURL = streamURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmedURL) else {
      castManager.lastError = "URL non valido"
      showError = true
      return
    }

    let mediaTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    castManager.castMedia(
      url: url,
      title: mediaTitle.isEmpty ? url.lastPathComponent : mediaTitle,
      mimeType: mimeType,
      subtitle: "Stream diretto"
    )

    if castManager.lastError != nil {
      showError = true
    }
  }

  private func exampleButton(title: String, url: String, mime: String) -> some View {
    Button(title) {
      streamURL = url
      mimeType = mime
      self.title = title
    }
  }
}

#Preview {
  ManualStreamView()
    .environmentObject(CastManager.shared)
}
