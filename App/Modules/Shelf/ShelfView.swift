import AppKit
import SwiftUI

struct ShelfView: View {
    let shelf: ShelfModule

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .foregroundStyle(.white.opacity(shelf.isTargeted ? 0.8 : 0.25))
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(shelf.isTargeted ? 0.1 : 0)))

            if shelf.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down").font(.title2)
                    Text("Drop files here").font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.items, id: \.self) { url in
                            ShelfItemView(url: url, shelf: shelf)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .contextMenu {
            if !shelf.items.isEmpty { Button("Clear Shelf") { shelf.clear() } }
        }
    }
}

private struct ShelfItemView: View {
    let url: URL
    let shelf: ShelfModule

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 40, height: 40)
            Text(url.lastPathComponent)
                .font(.system(size: 9)).foregroundStyle(.white)
                .lineLimit(1).truncationMode(.middle)
                .frame(width: 60)
        }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Remove") { shelf.remove(url) }
        }
    }
}
