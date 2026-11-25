import AppKit

/// Per-module switches and display choice, backed by UserDefaults (also read via @AppStorage).
enum Prefs {
    static let music = "module.music"
    static let shelf = "module.shelf"
    static let battery = "module.battery"
    static let headphones = "module.headphones"
    static let privacy = "module.privacy"
    static let bubble = "module.bubble"
    static let downloads = "module.downloads"
    static let focus = "module.focus"
    static let unlock = "module.unlock"
    /// "" = automatic (notch screen, else main), "main" = main display, otherwise a screen's localizedName.
    static let display = "display"

    static let displayChanged = Notification.Name("CoveDisplayChanged")

    static func register() {
        UserDefaults.standard.register(defaults: [
            music: true, shelf: true, battery: true, headphones: true, privacy: true, bubble: true,
            unlock: true,
            // These touch protected locations (Downloads folder, Focus database): opt-in.
            downloads: false, focus: false,
            display: "",
        ])
    }

    static func on(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
}
