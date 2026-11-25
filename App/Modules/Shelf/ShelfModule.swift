import AppKit
import SwiftUI
import Observation
import UniformTypeIdentifiers

/// Temporary file tray: keeps references to dropped files until removed or the app quits.
@Observable
final class ShelfModule: NotchModule {
    let id = "shelf"
    var items: [URL] = []
    var isTargeted = false
    var isAvailable: Bool { true }

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(url) { items.append(url) }
    }

    func remove(_ url: URL) { items.removeAll { $0 == url } }
    func clear() { items.removeAll() }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        for provider in fileProviders {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url else { return }
                DispatchQueue.main.async { self?.add([url]) }
            }
        }
        return !fileProviders.isEmpty
    }

    var compactView: some View { EmptyView() }
    var expandedView: some View { ShelfView(shelf: self) }
}
