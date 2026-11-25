import AppKit
import SwiftUI

/// First-launch welcome: how to use the island and opt-in toggles for permissioned features.
struct OnboardingView: View {
    let calendar: CalendarModule
    var onDone: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var meetings: Bool
    @State private var replaceHUD = MediaKeyInterceptor.shared.isEnabled

    init(calendar: CalendarModule, onDone: @escaping () -> Void) {
        self.calendar = calendar
        self.onDone = onDone
        _meetings = State(initialValue: calendar.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Cove").font(.system(size: 24, weight: .bold))
                    Text("A Dynamic Island for your Mac's notch.").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                tip("cursorarrow.rays", "Hover the notch to peek, click to expand.")
                tip("music.note", "Play music in Spotify or Apple Music to see it live.")
                tip("hand.draw", "Swipe two fingers on the island to skip tracks.")
                tip("tray.and.arrow.down", "Drag files onto the notch to hold them for later.")
                tip("capsule.fill", "Timer, settings and more live in the menu bar icon.")
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("Optional").font(.headline)
                option("Open at login", detail: "Start Cove automatically when you log in.", isOn: $launchAtLogin) {
                    LaunchAtLogin.set($0)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
                option("Upcoming meetings", detail: "Countdown and Join button before calls. Asks for Calendar access.",
                       isOn: $meetings) { calendar.setEnabled($0) }
                option("Volume & brightness HUD", detail: "Replace the macOS volume/brightness overlay. Asks for Accessibility.",
                       isOn: $replaceHUD) { MediaKeyInterceptor.shared.setEnabled($0) }
            }

            HStack {
                Text("Music access is requested the first time a song plays.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("Let's start!", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 480)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.tint)
            Text(text)
        }
    }

    private func option(_ title: String, detail: String, isOn: Binding<Bool>, apply: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { isOn.wrappedValue }, set: { isOn.wrappedValue = $0; apply($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

/// Shows the welcome window once, and on demand from the menu.
final class OnboardingController {
    static let doneKey = "onboardingDone"
    private var window: NSWindow?
    private let calendar: CalendarModule

    init(calendar: CalendarModule) {
        self.calendar = calendar
    }

    func showIfNeeded() {
        if !UserDefaults.standard.bool(forKey: Self.doneKey) { show() }
    }

    func show() {
        if window == nil {
            let view = OnboardingView(calendar: calendar) { [weak self] in
                UserDefaults.standard.set(true, forKey: Self.doneKey)
                self?.window?.close()
            }
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = "Welcome to Cove"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
