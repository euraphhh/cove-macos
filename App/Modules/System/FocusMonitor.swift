import Foundation
import SwiftUI

/// Focus mode changes. There is no public API, so this reads the DoNotDisturb database,
/// which needs Full Disk Access. Fragile by nature: any parsing failure simply shows nothing.
final class FocusMonitor {
    private let viewModel: NotchViewModel
    private var timer: Timer?
    private var current: String?
    private var primed = false

    private static let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    static var canRead: Bool { FileManager.default.isReadableFile(atPath: base.appendingPathComponent("Assertions.json").path) }

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.configure()
        }
        configure()
    }

    /// The timer only exists while the feature is on, so it costs nothing otherwise.
    private func configure() {
        if Prefs.on(Prefs.focus) {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }
        } else if timer != nil {
            timer?.invalidate()
            timer = nil
            primed = false
            current = nil
        }
    }

    private func poll() {
        guard Prefs.on(Prefs.focus), let state = Self.activeModeID() else { primed = false; return }
        let mode = state.isEmpty ? nil : state
        defer { current = mode; primed = true }
        guard primed, mode != current else { return }   // don't alert for the state found at launch

        if let mode, let info = Self.modeInfo(mode) {
            viewModel.show(IslandAlert(icon: info.symbol, iconColor: info.color, text: "On", textColor: info.color))
        } else if mode == nil, let old = current, let info = Self.modeInfo(old) {
            viewModel.show(IslandAlert(icon: info.symbol, iconColor: .gray, text: "Off", textColor: .gray))
        }
    }

    /// "" when no Focus is active, nil when the database can't be read.
    private static func activeModeID() -> String? {
        guard let data = try? Data(contentsOf: base.appendingPathComponent("Assertions.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else { return nil }
        let records = entries.first?["storeAssertionRecords"] as? [[String: Any]] ?? []
        let details = records.last?["assertionDetails"] as? [String: Any]
        return details?["assertionDetailsModeIdentifier"] as? String ?? ""
    }

    private static func modeInfo(_ id: String) -> (symbol: String, color: Color)? {
        guard let data = try? Data(contentsOf: base.appendingPathComponent("ModeConfigurations.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]],
              let configs = entries.first?["modeConfigurations"] as? [String: Any],
              let config = configs[id] as? [String: Any],
              let mode = config["mode"] as? [String: Any] else {
            return ("moon.fill", .indigo)
        }
        let symbol = mode["symbolImageName"] as? String ?? "moon.fill"
        return (symbol, color(named: mode["tintColorName"] as? String))
    }

    private static func color(named name: String?) -> Color {
        let n = (name ?? "").lowercased()
        let table: [(String, Color)] = [("indigo", .indigo), ("purple", .purple), ("blue", .blue), ("teal", .teal),
                                        ("cyan", .cyan), ("mint", .mint), ("green", .green), ("yellow", .yellow),
                                        ("orange", .orange), ("red", .red), ("pink", .pink), ("brown", .brown)]
        return table.first { n.contains($0.0) }?.1 ?? .indigo
    }
}
