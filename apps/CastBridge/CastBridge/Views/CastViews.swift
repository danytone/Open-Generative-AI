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
  @State private var isExpanded = false

  var body: some View {
    VStack(spacing: 0) {
      if castManager.streamDuration > 0 {
        ProgressView(value: castManager.streamPosition, total: castManager.streamDuration)
          .progressViewStyle(.linear)
          .tint(Color.accentColor)
      }

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
          castManager.skip(by: -10)
        } label: {
          Image(systemName: "gobackward.10")
        }

        Button {
          if castManager.isPlaying {
            castManager.pause()
          } else {
            castManager.play()
          }
        } label: {
          Image(systemName: castManager.isPlaying ? "pause.fill" : "play.fill")
        }

        Button {
          castManager.skip(by: 30)
        } label: {
          Image(systemName: "goforward.30")
        }

        Button {
          isExpanded.toggle()
        } label: {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      if isExpanded {
        PlayerControlsView()
          .padding(.horizontal, 16)
          .padding(.bottom, 12)
      }
    }
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

          HStack {
            Text("Chromecast rilevati")
            Spacer()
            Text("\(castManager.discoveredDeviceCount)")
              .foregroundStyle(.secondary)
          }

          if let deviceName = castManager.deviceName {
            HStack {
              Text("Connesso a")
              Spacer()
              Text(deviceName)
                .foregroundStyle(.secondary)
            }
          }

          Button {
            castManager.restartDiscovery()
          } label: {
            Label("Cerca di nuovo Chromecast", systemImage: "arrow.clockwise")
          }
        }

        Section("Riproduzione") {
          if let title = castManager.currentMediaTitle {
            Text(title)
              .font(.subheadline.weight(.medium))

            if castManager.isConnected {
              PlayerControlsView()
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            }
          } else {
            Text("Nessun contenuto in riproduzione")
              .foregroundStyle(.secondary)
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

        if castManager.discoveredDeviceCount == 0 {
          Section("Se non trovi il Chromecast") {
            VStack(alignment: .leading, spacing: 6) {
              Text("• iPhone e Chromecast devono essere sulla **stessa banda Wi‑Fi**. Molti Chromecast (1ª/2ª gen) supportano solo il 2.4GHz: se il mesh crea reti separate 2.4GHz/5GHz, l'iPhone potrebbe essere agganciato al nodo sbagliato.")
              Text("• Impostazioni → CastBridge → Rete locale deve essere **attivo**.")
              Text("• Chiudi del tutto l'app (swipe via) e riaprila dopo aver concesso i permessi.")
              Text("• Scollega e ricollega l'alimentazione del Chromecast.")
              Text("• Disattiva eventuali VPN sull'iPhone.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
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
