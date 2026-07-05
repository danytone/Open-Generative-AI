import SwiftUI

#if canImport(GoogleCast)
import GoogleCast
#endif

struct CastToolbarButton: View {
  var body: some View {
    #if canImport(GoogleCast)
    CastButtonRepresentable()
      .frame(width: 24, height: 24)
    #else
    Image(systemName: "airplayvideo")
      .foregroundStyle(.secondary)
    #endif
  }
}

#if canImport(GoogleCast)
struct CastButtonRepresentable: UIViewRepresentable {
  func makeUIView(context: Context) -> GCKUICastButton {
    let button = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
    button.tintColor = UIColor.tintColor
    return button
  }

  func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}
#endif

struct CastMiniController: View {
  @EnvironmentObject private var castManager: CastManager

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "tv.fill")
        .foregroundStyle(Color.accentColor)

      VStack(alignment: .leading, spacing: 2) {
        Text(castManager.deviceName ?? "Chromecast")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(castManager.currentMediaTitle ?? "In riproduzione")
          .font(.subheadline)
          .lineLimit(1)
      }

      Spacer()

      Button {
        if castManager.isPlaying {
          castManager.pause()
        } else {
          castManager.play()
        }
      } label: {
        Image(systemName: castManager.isPlaying ? "pause.fill" : "play.fill")
      }

      Button(role: .destructive) {
        castManager.stop()
      } label: {
        Image(systemName: "stop.fill")
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.ultraThinMaterial)
  }
}

struct CastStatusView: View {
  @EnvironmentObject private var castManager: CastManager

  var body: some View {
    NavigationStack {
      List {
        Section("Dispositivo") {
          HStack {
            Text("Stato")
            Spacer()
            Text(castManager.isConnected ? "Connesso" : "Disconnesso")
              .foregroundStyle(castManager.isConnected ? .green : .secondary)
          }

          if let deviceName = castManager.deviceName {
            HStack {
              Text("Chromecast")
              Spacer()
              Text(deviceName)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section("Riproduzione") {
          if let title = castManager.currentMediaTitle {
            HStack {
              Text("Titolo")
              Spacer()
              Text(title)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            }
          } else {
            Text("Nessun contenuto in riproduzione")
              .foregroundStyle(.secondary)
          }

          if castManager.isConnected {
            HStack {
              Button("Play") { castManager.play() }
              Spacer()
              Button("Pausa") { castManager.pause() }
              Spacer()
              Button("Stop", role: .destructive) { castManager.stop() }
            }
          }
        }

        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Come funziona")
              .font(.headline)
            Text("1. Connetti iPhone e Chromecast alla stessa rete Wi‑Fi.")
            Text("2. Tocca il pulsante Cast e seleziona il dispositivo.")
            Text("3. Scegli un video dal server UPnP o incolla un URL diretto.")
            Text("4. Il Chromecast scaricherà il flusso direttamente dal server locale.")
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        if let error = castManager.lastError {
          Section("Ultimo errore") {
            Text(error)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Chromecast")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          CastToolbarButton()
        }
      }
    }
  }
}

#Preview {
  CastStatusView()
    .environmentObject(CastManager.shared)
}
