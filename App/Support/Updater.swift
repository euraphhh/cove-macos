import Sparkle

/// Sparkle auto-updates. Feed URL and public key live in Info.plist (see scripts/bundle.sh).
final class Updater {
    static let shared = Updater()
    let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() { controller.checkForUpdates(nil) }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
}
