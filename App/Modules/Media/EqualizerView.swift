import SwiftUI

/// Animated bars shown in the compact live activity, like the iPhone's music island.
struct EqualizerView: View {
    var isPlaying: Bool
    var color: Color = .white
    private let speeds: [Double] = [1.7, 2.3, 1.3, 2.0]

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(speeds.indices, id: \.self) { i in
                    let wave = (sin(t * speeds[i] * .pi + Double(i)) + 1) / 2
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: isPlaying ? 4 + wave * 10 : 3)
                }
            }
            .frame(height: 14)
        }
        .animation(.easeOut(duration: 0.2), value: isPlaying)
    }
}
