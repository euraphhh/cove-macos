import SwiftUI

struct Artwork: View {
    let image: NSImage?
    var size: CGFloat
    var radius: CGFloat? = nil
    var body: some View {
        ZStack {
            Color.white.opacity(0.12)
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius ?? size / 4.5, style: .continuous))
        .animation(.easeInOut(duration: 0.3), value: image)
    }
}

struct MediaCompactView: View {
    let media: MediaModule
    var body: some View {
        Artwork(image: media.artwork, size: 19, radius: 5)
    }
}

/// iPhone-style expanded player: header, scrubber, centered transport.
struct MediaExpandedView: View {
    let media: MediaModule

    var body: some View {
        if let np = media.nowPlaying {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Artwork(image: media.artwork, size: 52, radius: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(np.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(np.artist).font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    EqualizerView(isPlaying: np.isPlaying, color: media.tint)
                }
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    let elapsed = np.elapsed(at: ctx.date)
                    HStack(spacing: 8) {
                        Text(Self.time(elapsed)).frame(width: 36, alignment: .leading)
                        LevelBar(value: np.duration > 0 ? elapsed / np.duration : 0, color: .white)
                        Text("-" + Self.time(max(np.duration - elapsed, 0))).frame(width: 40, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                }
                HStack(spacing: 44) {
                    TransportButton(icon: "backward.fill", size: 20) { media.send("previous track") }
                    TransportButton(icon: np.isPlaying ? "pause.fill" : "play.fill", size: 28) { media.send("playpause") }
                    TransportButton(icon: "forward.fill", size: 20) { media.send("next track") }
                }
            }
            .foregroundStyle(.white)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                Text("Nothing playing")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    static func time(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Transport button with a press-down scale, like iOS controls.
struct TransportButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size + 20, height: size + 12)
                .background(Circle().fill(.white.opacity(hovering ? 0.12 : 0)))
        }
        .buttonStyle(PressScaleStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
