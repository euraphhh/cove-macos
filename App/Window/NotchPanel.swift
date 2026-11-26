import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel, media: MediaModule, shelf: ShelfModule, timer: TimerModule, calendar: CalendarModule, privacy: PrivacyMonitor, registry: ActivityRegistry) {
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
        if let screen = NotchGeometry.targetScreen { alignToNotch(on: screen) }
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false

        let host = FirstMouseHostingView(rootView: NotchRootView(viewModel: viewModel, media: media, shelf: shelf, timer: timer, calendar: calendar, privacy: privacy, registry: registry))
        host.layer?.backgroundColor = .clear
        // The hosting view must never resize the window to fit its content: the panel keeps its
        // origin, so a wider window shifts the island off the notch.
        host.sizingOptions = []
        contentView = host
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [weak self] _ in
            self?.snapBack()
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition() {
        guard let screen = NotchGeometry.targetScreen else { return }
        viewModel.notchSize = NotchGeometry.notchSize(on: screen)
        viewModel.hasNotch = NotchGeometry.hasNotch(screen)
        setFrame(NotchGeometry.panelFrame(on: screen), display: true)
        alignToNotch(on: screen)
    }

    /// Anything that resizes or moves the panel puts it back on the notch.
    private func snapBack() {
        guard let screen = NotchGeometry.targetScreen else { return }
        let target = NotchGeometry.panelFrame(on: screen)
        if abs(frame.width - target.width) > 0.5 || abs(frame.midX - target.midX) > 1 { reposition() }
    }

    /// Window origins snap to whole points, but the notch center can sit on a half point
    /// (e.g. 735.5 on a 1470pt screen). Shift the drawing inside the panel by the remainder.
    private func alignToNotch(on screen: NSScreen) {
        viewModel.centerOffset = NotchGeometry.notchCenterX(on: screen) - frame.midX
    }
}

/// Lets the first click on the (never key) panel go straight to SwiftUI.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
