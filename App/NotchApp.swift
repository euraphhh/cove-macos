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
    private var power: PowerMonitor?
    private var bluetooth: BluetoothMonitor?
    private var volume: VolumeMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel(viewModel: viewModel, media: media, shelf: shelf)
        self.panel = panel
        panel.reposition()
        panel.orderFrontRegardless()

        hover = HoverTracker(panel: panel, viewModel: viewModel)
        media.start()
        menuBar = MenuBarController()
        power = PowerMonitor(viewModel: viewModel)
        power?.start()
        bluetooth = BluetoothMonitor(viewModel: viewModel)
        bluetooth?.start()
        volume = VolumeMonitor(viewModel: viewModel)
        volume?.start()
        MediaKeyInterceptor.shared.volume = volume
        MediaKeyInterceptor.shared.viewModel = viewModel
        MediaKeyInterceptor.shared.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.panel?.reposition() }
    }
}
