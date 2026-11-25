import CoreAudio
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
    @State private var showingRoutes = false
    /// Fraction (0...1) while the user drags the scrubber; nil otherwise.
    @State private var scrubbing: Double?

    var body: some View {
        if showingRoutes {
            RoutePicker(showingRoutes: $showingRoutes)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else if let np = media.nowPlaying {
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
                    let live = np.duration > 0 ? np.elapsed(at: ctx.date) / np.duration : 0
                    let elapsed = (scrubbing ?? live) * np.duration
                    HStack(spacing: 8) {
                        Text(Self.time(elapsed)).frame(width: 36, alignment: .leading)
                        ScrubBar(value: scrubbing ?? live, scrubbing: $scrubbing) { fraction in
                            media.seek(to: fraction * np.duration)
                        }
                        Text("-" + Self.time(max(np.duration - elapsed, 0))).frame(width: 40, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(scrubbing != nil ? 0.9 : 0.55))
                }
                ZStack {
                    HStack(spacing: 44) {
                        TransportButton(icon: "backward.fill", size: 20) { media.send("previous track") }
                        TransportButton(icon: np.isPlaying ? "pause.fill" : "play.fill", size: 28) { media.send("playpause") }
                        TransportButton(icon: "forward.fill", size: 20) { media.send("next track") }
                    }
                    HStack { Spacer(); RouteButton(showingRoutes: $showingRoutes) }
                }
            }
            .foregroundStyle(.white)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
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

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(CircleHighlightStyle(diameter: size * 1.9, layout: CGSize(width: size + 20, height: size + 12)))
    }
}

/// iOS-style control: a translucent circle that fully covers the button on hover/press.
struct CircleHighlightStyle: ButtonStyle {
    var diameter: CGFloat
    /// Space the button takes in the layout; the circle may overflow it without growing the island.
    var layout: CGSize? = nil
    func makeBody(configuration: Configuration) -> some View {
        HighlightBody(configuration: configuration, diameter: diameter,
                      layout: layout ?? CGSize(width: diameter, height: diameter))
    }

    private struct HighlightBody: View {
        let configuration: Configuration
        let diameter: CGFloat
        let layout: CGSize
        @State private var hovering = false
        var body: some View {
            configuration.label
                .frame(width: layout.width, height: layout.height)
                .contentShape(Rectangle())
                .background(
                    Circle().fill(.white.opacity(configuration.isPressed ? 0.24 : hovering ? 0.13 : 0))
                        .frame(width: diameter, height: diameter)
                )
                .scaleEffect(configuration.isPressed ? 0.88 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: hovering)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// AirPlay-style button; its icon reflects the current output (AirPods, speaker...).
struct RouteButton: View {
    @Binding var showingRoutes: Bool
    var body: some View {
        let current = AudioOutputs.all().first { $0.id == AudioOutputs.currentID }
        let icon = current.map { $0.transport == kAudioDeviceTransportTypeBuiltIn ? "airplayaudio" : $0.icon } ?? "airplayaudio"
        Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showingRoutes.toggle() } } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(current?.transport == kAudioDeviceTransportTypeBuiltIn ? .white.opacity(0.7) : .blue)
        }
        .buttonStyle(CircleHighlightStyle(diameter: 34))
    }
}

/// Inline output picker that replaces the player, like the iOS route sheet.
struct RoutePicker: View {
    @Binding var showingRoutes: Bool
    @State private var outputs = AudioOutputs.all()
    @State private var current = AudioOutputs.currentID
    @State private var volume = Double(AudioOutputs.volume ?? 0.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Audio Output").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showingRoutes = false } } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(PressScaleStyle())
            }
            VolumePill(value: $volume) { AudioOutputs.setVolume(Float($0)) }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(outputs) { output in
                        Button {
                            AudioOutputs.select(output)
                            current = output.id
                            volume = Double(AudioOutputs.volume ?? Float(volume))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showingRoutes = false }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: output.icon).font(.system(size: 15)).frame(width: 24)
                                Text(output.name).font(.system(size: 14)).lineLimit(1)
                                Spacer()
                                if output.id == current {
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.blue)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(output.id == current ? 0.1 : 0)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
        .onAppear {
            outputs = AudioOutputs.all()
            current = AudioOutputs.currentID
            volume = Double(AudioOutputs.volume ?? 0.5)
        }
    }
}

/// Progress bar you can drag or click to seek; thickens on hover like iOS.
struct ScrubBar: View {
    var value: Double
    @Binding var scrubbing: Double?
    var onCommit: (Double) -> Void
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let active = hovering || scrubbing != nil
            let fraction = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white).frame(width: geo.size.width * fraction)
            }
            .frame(height: active ? 9 : 5)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in scrubbing = min(max(g.location.x / geo.size.width, 0), 1) }
                    .onEnded { g in
                        let f = min(max(g.location.x / geo.size.width, 0), 1)
                        onCommit(f)
                        // Hold the dragged value briefly so the bar doesn't jump back before the player catches up.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scrubbing = nil }
                    }
            )
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: active)
        }
        .frame(height: 16)
    }
}

/// Thick pill slider like the iOS volume control: fills white, speaker glyph inside.
struct VolumePill: View {
    @Binding var value: Double
    var onChange: (Double) -> Void
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Rectangle().fill(.white).frame(width: w * value)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(value > 0.12 ? .black.opacity(0.55) : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.leading, 12)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .scaleEffect(dragging ? 1.03 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        dragging = true
                        value = min(max(g.location.x / w, 0), 1)
                        onChange(value)
                    }
                    .onEnded { _ in dragging = false }
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: dragging)
        }
        .frame(height: 30)
    }

    private var icon: String {
        switch value {
        case 0: "speaker.slash.fill"
        case ..<0.34: "speaker.wave.1.fill"
        case ..<0.67: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}
