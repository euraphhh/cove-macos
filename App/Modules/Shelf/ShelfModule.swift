import AppKit
import SwiftUI
import Observation
import UniformTypeIdentifiers

/// One thing parked on the Shelf.
struct ShelfItem: Identifiable, Codable, Equatable {
    enum Kind: Codable, Equatable {
        /// A file somewhere on disk; Cove only remembers where.
        case file(URL)
        /// A file Cove saved itself (images dropped from a browser); deleted together with the item.
        case stored(URL)
        case link(URL)
        case text(String)
    }

    var id = UUID()
    var kind: Kind

    /// File on disk behind this item, if any.
    var fileURL: URL? {
        switch kind {
        case .file(let url), .stored(let url): url
        case .link, .text: nil
        }
    }

    var title: String {
        switch kind {
        case .file(let url), .stored(let url): url.lastPathComponent
        case .link(let url): url.host(percentEncoded: false) ?? url.absoluteString
        case .text(let text): String(text.prefix(40))
        }
    }

    /// What gets dragged out of the island.
    var itemProvider: NSItemProvider {
        switch kind {
        case .file(let url), .stored(let url): NSItemProvider(contentsOf: url) ?? NSItemProvider()
        case .link(let url): NSItemProvider(object: url as NSURL)
        case .text(let text): NSItemProvider(object: text as NSString)
        }
    }
}

/// Tray for files, images, links and text. Survives restarts (saved as JSON in Application Support).
@Observable
final class ShelfModule: NotchModule {
    let id = "shelf"
    private(set) var items: [ShelfItem] = []
    var isTargeted = false
    var isAvailable: Bool { true }

    /// Everything the island accepts as a drop.
    static let acceptedTypes: [UTType] = [.fileURL, .url, .image, .plainText]

    static var defaultDirectory: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Cove/Shelf", isDirectory: true)
    }

    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("shelf.json") }

    init(directory: URL = ShelfModule.defaultDirectory) {
        self.directory = directory
        items = load()
    }

    // MARK: Adding

    func add(_ urls: [URL]) {
        for url in urls { append(.file(url)) }
    }

    func addLink(_ url: URL) { append(.link(url)) }

    func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(.text(trimmed))
    }

    /// Saves the image as a PNG inside Cove's folder so it can be dragged out as a normal file.
    func addImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        let url = directory.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: url)
            append(.stored(url))
        } catch {
            Log.app.error("Shelf could not save image: \(error.localizedDescription)")
        }
    }

    private func append(_ kind: ShelfItem.Kind) {
        guard !items.contains(where: { $0.kind == kind }) else { return }
        items.append(ShelfItem(kind: kind))
        save()
    }

    // MARK: Removing

    func remove(_ item: ShelfItem) {
        discard(item)
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.forEach(discard)
        items.removeAll()
        save()
    }

    private func discard(_ item: ShelfItem) {
        if case .stored(let url) = item.kind { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: Dropping

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { self?.add([url]) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                accepted = true
                _ = provider.loadObject(ofClass: NSImage.self) { [weak self] image, _ in
                    guard let image else { return }
                    DispatchQueue.main.async { self?.addImage(image) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                accepted = true
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { self?.addLink(url) }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                accepted = true
                _ = provider.loadObject(ofClass: String.self) { [weak self] text, _ in
                    guard let text else { return }
                    DispatchQueue.main.async { self?.addText(text) }
                }
            }
        }
        return accepted
    }

    // MARK: Persistence

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
        } catch {
            Log.app.error("Shelf could not save: \(error.localizedDescription)")
        }
    }

    /// Drops items whose files were moved or deleted while Cove wasn't running.
    private func load() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return [] }
        return saved.filter { item in
            guard let url = item.fileURL else { return true }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    var compactView: some View { EmptyView() }
    var expandedView: some View { ShelfView(shelf: self) }
}
