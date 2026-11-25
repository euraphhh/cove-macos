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
    private var swipe: SwipeHandler?
    private let viewModel = NotchViewModel()
    private let media = MediaModule()
    private let shelf = ShelfModule()
    private let timer = TimerModule()
    private let calendar = CalendarModule()
    private var menuBar: MenuBarController?
    private var power: PowerMonitor?
    private var bluetooth: BluetoothMonitor?
    private var volume: VolumeMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel(viewModel: viewModel, media: media, shelf: shelf, timer: timer, calendar: calendar)
        self.panel = panel
        panel.reposition()
        panel.orderFrontRegardless()

        hover = HoverTracker(panel: panel, viewModel: viewModel)
        swipe = SwipeHandler(panel: panel, viewModel: viewModel, media: media)
        media.start()
        calendar.onStart = { [viewModel] meeting in
            viewModel.show(IslandAlert(icon: "calendar", iconColor: meeting.color, text: "Now", textColor: meeting.color), for: 4)
        }
        calendar.start()
        timer.onFinish = { [viewModel] in
            viewModel.show(IslandAlert(icon: "timer", iconColor: .orange, text: "Done", textColor: .orange), for: 4)
        }
        menuBar = MenuBarController(timer: timer, calendar: calendar)
        power = PowerMonitor(viewModel: viewModel)
        power?.start()
        DebugHooks.install(viewModel: viewModel, power: power, calendar: calendar)
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
