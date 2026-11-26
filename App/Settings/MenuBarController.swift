import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchItem = NSMenuItem(title: String(localized: "Launch at Login"), action: #selector(toggleLaunch), keyEquivalent: "")
    private let hudItem = NSMenuItem(title: String(localized: "Replace System Volume/Brightness HUD"), action: #selector(toggleHUD), keyEquivalent: "")
    private var settingsWindow: NSWindow?

    private let timer: TimerModule
    private let calendar: CalendarModule
    private let calendarItem = NSMenuItem(title: String(localized: "Show Upcoming Meetings"), action: #selector(toggleCalendar), keyEquivalent: "")

    private let onboarding: OnboardingController

    init(timer: TimerModule, calendar: CalendarModule, onboarding: OnboardingController) {
        self.onboarding = onboarding
        self.timer = timer
        self.calendar = calendar
        super.init()
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Cove")
        let menu = NSMenu()
        menu.delegate = self
        launchItem.target = self
        let settings = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        hudItem.target = self
        let timerItem = NSMenuItem(title: String(localized: "Timer"), action: nil, keyEquivalent: "")
        let timerMenu = NSMenu()
        for minutes in [1, 5, 10, 15, 25, 30, 60] {
            let item = NSMenuItem(title: String(localized: "\(minutes) min"), action: #selector(startTimer(_:)), keyEquivalent: "")
            item.tag = minutes
            item.target = self
            timerMenu.addItem(item)
        }
        timerMenu.addItem(.separator())
        let cancel = NSMenuItem(title: String(localized: "Cancel Timer"), action: #selector(cancelTimer), keyEquivalent: "")
        cancel.target = self
        timerMenu.addItem(cancel)
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)
        calendarItem.target = self
        menu.addItem(calendarItem)
        menu.addItem(.separator())
        menu.addItem(launchItem)
        menu.addItem(hudItem)
        menu.addItem(settings)
        let welcome = NSMenuItem(title: String(localized: "Welcome…"), action: #selector(showWelcome), keyEquivalent: "")
        welcome.target = self
        menu.addItem(welcome)
        let feedback = NSMenuItem(title: String(localized: "Send Feedback…"), action: #selector(sendFeedback), keyEquivalent: "")
        feedback.target = self
        menu.addItem(feedback)
        let updates = NSMenuItem(title: String(localized: "Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Cove"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        calendarItem.state = calendar.isEnabled ? .on : .off
        hudItem.state = MediaKeyInterceptor.shared.isEnabled ? .on : .off
    }

    @objc private func toggleLaunch() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func startTimer(_ sender: NSMenuItem) { timer.start(minutes: Double(sender.tag)) }
    @objc private func cancelTimer() { timer.cancel() }

    @objc private func sendFeedback() { Feedback.open() }

    @objc private func showWelcome() { onboarding.show() }

    @objc private func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        Updater.shared.checkForUpdates()
    }

    @objc private func toggleCalendar() { calendar.setEnabled(!calendar.isEnabled) }

    @objc private func toggleHUD() {
        MediaKeyInterceptor.shared.setEnabled(!MediaKeyInterceptor.shared.isEnabled)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = String(localized: "Cove Settings")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
