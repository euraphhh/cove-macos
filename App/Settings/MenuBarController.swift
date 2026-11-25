import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunch), keyEquivalent: "")
    private let hudItem = NSMenuItem(title: "Replace System Volume/Brightness HUD", action: #selector(toggleHUD), keyEquivalent: "")
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Cove")
        let menu = NSMenu()
        menu.delegate = self
        launchItem.target = self
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        hudItem.target = self
        menu.addItem(launchItem)
        menu.addItem(hudItem)
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Cove", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        hudItem.state = MediaKeyInterceptor.shared.isEnabled ? .on : .off
    }

    @objc private func toggleLaunch() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

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
