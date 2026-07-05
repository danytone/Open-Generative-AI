import SwiftUI

struct PlayerControlsView: View {
  @EnvironmentObject private var castManager: CastManager
  @State private var isScrubbing = false
  @State private var scrubPosition: TimeInterval = 0

  private var displayedPosition: TimeInterval {
    isScrubbing ? scrubPosition : castManager.streamPosition
  }

  var body: some View {
    VStack(spacing: 16) {
      progressSection
      transportControls
      volumeSection
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private var progressSection: some View {
    VStack(spacing: 4) {
      Slider(
        value: Binding(
          get: { displayedPosition },
          set: { newValue in
            isScrubbing = true
            scrubPosition = newValue
          }
        ),
        in: 0...max(castManager.streamDuration, 1),
        onEditingChanged: { editing in
          if !editing {
            castManager.seek(to: scrubPosition)
            isScrubbing = false
          }
        }
      )
      .disabled(castManager.streamDuration <= 0)

      HStack {
        Text(formatted(displayedPosition))
        Spacer()
        if castManager.isBuffering {
          ProgressView()
            .scaleEffect(0.7)
        }
        Spacer()
        Text(formatted(castManager.streamDuration))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .monospacedDigit()
    }
  }

  private var transportControls: some View {
    HStack(spacing: 32) {
      Button {
        castManager.skip(by: -10)
      } label: {
        Image(systemName: "gobackward.10")
          .font(.title2)
      }

      Button {
        if castManager.isPlaying {
          castManager.pause()
        } else {
          castManager.play()
        }
      } label: {
        Image(systemName: castManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.system(size: 48))
      }

      Button {
        castManager.skip(by: 30)
      } label: {
        Image(systemName: "goforward.30")
          .font(.title2)
      }

      Button(role: .destructive) {
        castManager.stop()
      } label: {
        Image(systemName: "stop.circle.fill")
          .font(.title2)
      }
    }
    .foregroundStyle(Color.accentColor)
  }

  private var volumeSection: some View {
    HStack(spacing: 12) {
      Button {
        castManager.toggleMute()
      } label: {
        Image(systemName: castManager.isMuted ? "speaker.slash.fill" : volumeIcon)
      }
      .frame(width: 24)

      Slider(
        value: Binding(
          get: { castManager.deviceVolume },
          set: { castManager.setVolume($0) }
        ),
        in: 0...1
      )
    }
    .foregroundStyle(.secondary)
  }

  private var volumeIcon: String {
    switch castManager.deviceVolume {
    case 0: return "speaker.fill"
    case ..<0.34: return "speaker.wave.1.fill"
    case ..<0.67: return "speaker.wave.2.fill"
    default: return "speaker.wave.3.fill"
    }
  }

  private func formatted(_ interval: TimeInterval) -> String {
    guard interval.isFinite, interval >= 0 else { return "0:00" }
    let totalSeconds = Int(interval)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
  }
}

#Preview {
  PlayerControlsView()
    .environmentObject(CastManager.shared)
    .padding()
}
