import AppKit
import SwiftUI

@main
struct NotchApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var hover: HoverTracker?
    private let viewModel = NotchViewModel()
    private let media = MediaModule()
    private let shelf = ShelfModule()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel(viewModel: viewModel, media: media, shelf: shelf)
        self.panel = panel
        panel.reposition()
        panel.orderFrontRegardless()

        hover = HoverTracker(panel: panel, viewModel: viewModel)
        media.start()
        menuBar = MenuBarController()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.panel?.reposition() }
    }
}
