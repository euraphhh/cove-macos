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
                    Text("Drop files, links or text").font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.items) { item in
                            ShelfItemView(item: item, shelf: shelf)
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
    let item: ShelfItem
    let shelf: ShelfModule

    var body: some View {
        VStack(spacing: 4) {
            thumbnail.frame(width: 40, height: 40)
                .opacity(shelf.working.contains(item.id) ? 0.35 : 1)
                .overlay {
                    if shelf.working.contains(item.id) { ProgressView().controlSize(.small) }
                }
            Text(item.title)
                .font(.system(size: 9)).foregroundStyle(.white)
                .lineLimit(1).truncationMode(.middle)
                .frame(width: 60)
        }
        .onDrag { item.itemProvider }
        .contextMenu { menu }
    }

    @ViewBuilder private var thumbnail: some View {
        switch item.kind {
        case .file(let url):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        case .stored(let url):
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            }
        case .link:
            symbol("link")
        case .text:
            symbol("text.alignleft")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 40, height: 40)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.12)))
    }

    @ViewBuilder private var menu: some View {
        ForEach(ShelfActions.available(for: item)) { action in
            Button { shelf.perform(action, on: item) } label: { Label(action.title, systemImage: action.symbol) }
        }
        Divider()
        switch item.kind {
        case .file(let url), .stored(let url):
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        case .link(let url):
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Copy") { copy(url.absoluteString) }
        case .text(let text):
            Button("Copy") { copy(text) }
        }
        Button("Remove") { shelf.remove(item) }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
