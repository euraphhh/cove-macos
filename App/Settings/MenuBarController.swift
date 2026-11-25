import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunch), keyEquivalent: "")
    private let hudItem = NSMenuItem(title: "Replace System Volume/Brightness HUD", action: #selector(toggleHUD), keyEquivalent: "")
    private var settingsWindow: NSWindow?

    private let timer: TimerModule
    private let calendar: CalendarModule
    private let calendarItem = NSMenuItem(title: "Show Upcoming Meetings", action: #selector(toggleCalendar), keyEquivalent: "")

    init(timer: TimerModule, calendar: CalendarModule) {
        self.timer = timer
        self.calendar = calendar
        super.init()
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Cove")
        let menu = NSMenu()
        menu.delegate = self
        launchItem.target = self
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        hudItem.target = self
        let timerItem = NSMenuItem(title: "Timer", action: nil, keyEquivalent: "")
        let timerMenu = NSMenu()
        for minutes in [1, 5, 10, 15, 25, 30, 60] {
            let item = NSMenuItem(title: "\(minutes) min", action: #selector(startTimer(_:)), keyEquivalent: "")
            item.tag = minutes
            item.target = self
            timerMenu.addItem(item)
        }
        timerMenu.addItem(.separator())
        let cancel = NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimer), keyEquivalent: "")
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
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Cove", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
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
            w.title = "Cove Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
