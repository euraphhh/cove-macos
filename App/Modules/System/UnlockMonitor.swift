import Foundation
import SwiftUI

/// Lock-opening animation when the Mac is unlocked, like Face ID on iPhone.
final class UnlockMonitor {
    private let viewModel: NotchViewModel

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.play() }
    }

    func play() {
        guard Prefs.on(Prefs.unlock) else { return }
        viewModel.show(IslandAlert(icon: "lock.fill", iconColor: .white, text: ""), for: 1.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.viewModel.update(IslandAlert(icon: "lock.open.fill", iconColor: .white, text: ""))
        }
    }
}
