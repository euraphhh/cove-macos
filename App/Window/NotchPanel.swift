import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel, media: MediaModule, shelf: ShelfModule, timer: TimerModule, calendar: CalendarModule, privacy: PrivacyMonitor, downloads: DownloadModule) {
        self.viewModel = viewModel
        // Start at the final frame so nothing animates in from the corner at launch.
        let initial = NotchGeometry.targetScreen.map(NotchGeometry.panelFrame(on:)) ?? .zero
        if let screen = NotchGeometry.targetScreen {
            viewModel.notchSize = NotchGeometry.notchSize(on: screen)
            viewModel.hasNotch = NotchGeometry.hasNotch(screen)
        }
        super.init(contentRect: initial,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false

        let host = FirstMouseHostingView(rootView: NotchRootView(viewModel: viewModel, media: media, shelf: shelf, timer: timer, calendar: calendar, privacy: privacy, downloads: downloads))
        host.layer?.backgroundColor = .clear
        contentView = host
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition() {
        guard let screen = NotchGeometry.targetScreen else { return }
        viewModel.notchSize = NotchGeometry.notchSize(on: screen)
        viewModel.hasNotch = NotchGeometry.hasNotch(screen)
        setFrame(NotchGeometry.panelFrame(on: screen), display: true)
    }
}

/// Lets the first click on the (never key) panel go straight to SwiftUI.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
