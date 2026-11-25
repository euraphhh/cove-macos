import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel, media: MediaModule, shelf: ShelfModule) {
        self.viewModel = viewModel
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false

        let host = NSHostingView(rootView: NotchRootView(viewModel: viewModel, media: media, shelf: shelf))
        host.layer?.backgroundColor = .clear
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition() {
        guard let screen = NotchGeometry.targetScreen else { return }
        viewModel.notchSize = NotchGeometry.notchSize(on: screen)
        setFrame(NotchGeometry.panelFrame(on: screen), display: true)
    }
}
