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
    private let privacy = PrivacyMonitor()
    private let downloads = DownloadModule()
    private let registry = ActivityRegistry()
    private var focus: FocusMonitor?
    private var unlock: UnlockMonitor?
    private var screenshots: ScreenshotWatcher?
    private var network: NetworkMonitor?
    private var menuBar: MenuBarController?
    private var onboarding: OnboardingController?
    private var appliedHotKey: HotKey.Preset = .controlOption
    private var keyboardCloseWork: DispatchWorkItem?

    private func toggleFromKeyboard() {
        keyboardCloseWork?.cancel()
        if viewModel.state == .expanded {
            viewModel.openedByKeyboard = false
            viewModel.state = .closed
            panel?.ignoresMouseEvents = true
            return
        }
        viewModel.openedByKeyboard = true
        viewModel.state = .expanded
        panel?.ignoresMouseEvents = false
        // Close on its own if the cursor never comes over.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.viewModel.openedByKeyboard else { return }
            self.viewModel.openedByKeyboard = false
            self.viewModel.state = .closed
            self.panel?.ignoresMouseEvents = true
        }
        keyboardCloseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }
    private var power: PowerMonitor?
    private var bluetooth: BluetoothMonitor?
    private var volume: VolumeMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        // Priority order comes from `Activity`, not from registration order.
        registry.register(timer)
        registry.register(calendar)
        registry.register(downloads)
        registry.register(media)
        let panel = NotchPanel(viewModel: viewModel, media: media, shelf: shelf, timer: timer, calendar: calendar, privacy: privacy, registry: registry)
        self.panel = panel
        panel.reposition()
        panel.orderFrontRegardless()

        shelf.onFeedback = { [viewModel] symbol, text in
            viewModel.show(IslandAlert(icon: symbol, iconColor: .white, text: text))
        }
        hover = HoverTracker(panel: panel, viewModel: viewModel)
        swipe = SwipeHandler(panel: panel, viewModel: viewModel, media: media)
        media.start()
        privacy.start()
        WeatherModule.shared.start()
        downloads.onFinish = { [viewModel] _ in
            viewModel.show(IslandAlert(icon: "checkmark.circle.fill", iconColor: .blue, text: String(localized: "Done"), textColor: .blue))
        }
        downloads.start()
        focus = FocusMonitor(viewModel: viewModel)
        focus?.start()
        unlock = UnlockMonitor(viewModel: viewModel)
        unlock?.start()
        screenshots = ScreenshotWatcher(viewModel: viewModel, shelf: shelf)
        screenshots?.start()
        network = NetworkMonitor(viewModel: viewModel)
        network?.start()
        calendar.onStart = { [viewModel] meeting in
            viewModel.show(IslandAlert(icon: "calendar", iconColor: meeting.color, text: String(localized: "Now"), textColor: meeting.color), for: 4)
        }
        calendar.start()
        timer.onFinish = { [viewModel] in
            viewModel.show(IslandAlert(icon: "timer", iconColor: .orange, text: String(localized: "Done"), textColor: .orange), for: 4)
        }
        _ = Updater.shared
        HotKey.shared.onPress = { [weak self] in self?.toggleFromKeyboard() }
        HotKey.shared.apply(HotKey.Preset(rawValue: UserDefaults.standard.string(forKey: Prefs.hotKey) ?? "") ?? .controlOption)
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            let preset = HotKey.Preset(rawValue: UserDefaults.standard.string(forKey: Prefs.hotKey) ?? "") ?? .controlOption
            if preset != self.appliedHotKey { self.appliedHotKey = preset; HotKey.shared.apply(preset) }
        }
        let onboarding = OnboardingController(calendar: calendar)
        self.onboarding = onboarding
        menuBar = MenuBarController(timer: timer, calendar: calendar, onboarding: onboarding)
        onboarding.showIfNeeded()
        power = PowerMonitor(viewModel: viewModel)
        power?.start()
        DebugHooks.install(viewModel: viewModel, power: power, calendar: calendar, timer: timer, privacy: privacy, unlock: unlock, downloads: downloads)
        bluetooth = BluetoothMonitor(viewModel: viewModel)
        bluetooth?.start()
        volume = VolumeMonitor(viewModel: viewModel)
        volume?.start()
        MediaKeyInterceptor.shared.volume = volume
        MediaKeyInterceptor.shared.viewModel = viewModel
        MediaKeyInterceptor.shared.start()

        NotificationCenter.default.addObserver(forName: Prefs.displayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.panel?.reposition()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.panel?.reposition() }
    }
}
