import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var replaceHUD = MediaKeyInterceptor.shared.isEnabled
    @State private var autoUpdate = Updater.shared.automaticallyChecks

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, value in
                    LaunchAtLogin.set(value)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            Toggle("Replace system volume/brightness HUD", isOn: $replaceHUD)
                .onChange(of: replaceHUD) { _, value in MediaKeyInterceptor.shared.setEnabled(value) }
            Text("Requires Accessibility permission.").font(.footnote).foregroundStyle(.secondary)
            Toggle("Automatically check for updates", isOn: $autoUpdate)
                .onChange(of: autoUpdate) { _, value in Updater.shared.automaticallyChecks = value }
            Text("Cove \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 260)
    }
}
