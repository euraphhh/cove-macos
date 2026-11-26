import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var replaceHUD = MediaKeyInterceptor.shared.isEnabled
    @State private var autoUpdate = Updater.shared.automaticallyChecks

    @AppStorage(Prefs.music) private var music = true
    @AppStorage(Prefs.shelf) private var shelf = true
    @AppStorage(Prefs.battery) private var battery = true
    @AppStorage(Prefs.headphones) private var headphones = true
    @AppStorage(Prefs.privacy) private var privacy = true
    @AppStorage(Prefs.bubble) private var bubble = true
    @AppStorage(Prefs.downloads) private var downloads = false
    @AppStorage(Prefs.focus) private var focus = false
    @AppStorage(Prefs.unlock) private var unlock = true
    @AppStorage(Prefs.screenshots) private var screenshots = true
    @AppStorage(Prefs.network) private var network = true
    @AppStorage(Prefs.lowPower) private var lowPower = true
    @AppStorage(Prefs.display) private var display = ""

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in
                        LaunchAtLogin.set(value)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                Picker("Show on", selection: $display) {
                    Text("Automatic").tag("")
                    Text("Main display").tag("main")
                    ForEach(NSScreen.screens.map(\.localizedName), id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: display) { NotificationCenter.default.post(name: Prefs.displayChanged, object: nil) }
                Toggle("Automatically check for updates", isOn: $autoUpdate)
                    .onChange(of: autoUpdate) { _, value in Updater.shared.automaticallyChecks = value }
            }

            Section("Live activities") {
                Toggle("Music", isOn: $music)
                Toggle("Show a second activity as a bubble", isOn: $bubble)
                Toggle("Downloads", isOn: $downloads)
                if downloads { note("macOS asks once for access to your Downloads folder.") }
            }

            Section("Alerts") {
                Toggle("Charger and low battery", isOn: $battery)
                Toggle("Low Power Mode", isOn: $lowPower)
                Toggle("Online / offline", isOn: $network)
                Toggle("New screenshots (added to the Shelf)", isOn: $screenshots)
                Toggle("Headphones connected", isOn: $headphones)
                Toggle("Unlock animation", isOn: $unlock)
                Toggle("Focus mode changes", isOn: $focus)
                if focus {
                    HStack {
                        note(FocusMonitor.canRead ? "Reading Focus status." : "Needs Full Disk Access to read Focus status.")
                        Spacer()
                        if !FocusMonitor.canRead {
                            Button("Open Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                            }
                        }
                    }
                }
            }

            Section("Other") {
                Toggle("Shelf (drop files on the notch)", isOn: $shelf)
                Toggle("Camera and microphone indicator", isOn: $privacy)
                Toggle("Replace system volume/brightness HUD", isOn: $replaceHUD)
                    .onChange(of: replaceHUD) { _, value in MediaKeyInterceptor.shared.setEnabled(value) }
                note("Requires Accessibility permission.")
            }

            Text("Cove \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 680)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.footnote).foregroundStyle(.secondary)
    }
}
