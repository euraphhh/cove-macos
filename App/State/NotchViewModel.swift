import SwiftUI
import Observation

enum NotchState { case closed, peek, expanded }

/// Short-lived activity that takes over the compact island (charger, AirPods, ...).
struct IslandAlert: Equatable {
    var icon: String
    var iconColor: Color
    var text: String
    var textColor: Color = .white
}

@Observable
final class NotchViewModel {
    var state: NotchState = .closed
    var notchSize: CGSize = CGSize(width: 200, height: 32)
    /// A live activity (e.g. music playing) widens the closed island around the notch.
    var hasLiveActivity = false
    private(set) var alert: IslandAlert?
    private var alertTask: Task<Void, Never>?

    /// Width of each "wing" beside the physical notch.
    var wingWidth: CGFloat { alert != nil ? notchSize.height + 24 : notchSize.height + 6 }

    var closedSize: CGSize {
        let widened = hasLiveActivity || alert != nil
        return widened ? CGSize(width: notchSize.width + wingWidth * 2, height: notchSize.height) : notchSize
    }

    /// Slightly bigger island while hovering, before a click expands it.
    var peekSize: CGSize { CGSize(width: closedSize.width + 16, height: closedSize.height + 4) }

    func show(_ alert: IslandAlert, for seconds: Double = 2.5) {
        alertTask?.cancel()
        self.alert = alert
        alertTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.alert = nil
        }
    }
}
