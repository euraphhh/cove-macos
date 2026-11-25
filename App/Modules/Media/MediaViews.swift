import SwiftUI

struct Artwork: View {
    let url: URL?
    var size: CGFloat
    var body: some View {
        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: {
            Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: size, height: size)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: size / 5))
    }
}

struct MediaCompactView: View {
    let media: MediaModule
    var body: some View {
        if let np = media.nowPlaying {
            Artwork(url: np.artworkURL, size: 18)
        }
    }
}

struct MediaExpandedView: View {
    let media: MediaModule
    var body: some View {
        if let np = media.nowPlaying {
            HStack(spacing: 14) {
                Artwork(url: np.artworkURL, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(np.title).font(.headline).lineLimit(1)
                    Text(np.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 22) {
                        button("backward.fill") { media.send("previous track") }
                        button(np.isPlaying ? "pause.fill" : "play.fill") { media.send("playpause") }
                        button("forward.fill") { media.send("next track") }
                    }
                    .padding(.top, 6)
                }
                Spacer()
            }
            .foregroundStyle(.white)
        } else {
            Text("Nothing playing").foregroundStyle(.white.opacity(0.6))
        }
    }

    private func button(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title3) }.buttonStyle(.plain)
    }
}
