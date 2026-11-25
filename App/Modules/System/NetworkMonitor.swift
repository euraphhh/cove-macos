import Foundation
import Network
import SwiftUI

/// Alerts when the Mac goes offline or comes back online (no network name: that needs Location access).
final class NetworkMonitor {
    private let viewModel: NotchViewModel
    private let monitor = NWPathMonitor()
    private var online: Bool?
    private var pending: DispatchWorkItem?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.update(path) }
        }
        monitor.start(queue: DispatchQueue(label: "cove.network"))
    }

    private func update(_ path: NWPath) {
        let isOnline = path.status == .satisfied
        let wifi = path.usesInterfaceType(.wifi)
        guard let previous = online else { online = isOnline; return }   // ignore the state at launch
        guard isOnline != previous else { return }
        online = isOnline
        // Paths flap briefly while switching networks; only report a state that holds for 2s.
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.online == isOnline, Prefs.on(Prefs.network) else { return }
            let alert = isOnline
                ? IslandAlert(icon: wifi ? "wifi" : "network", iconColor: .white, text: "Online", textColor: .green)
                : IslandAlert(icon: "wifi.slash", iconColor: .red, text: "Offline", textColor: .red)
            self.viewModel.show(alert)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
}
