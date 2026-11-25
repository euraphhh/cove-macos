import SwiftUI
import Observation

enum NotchState { case closed, peek, expanded }

/// Short-lived activity that takes over the compact island (charger, AirPods, ...).
struct IslandAlert: Equatable {
    var icon: String
    var iconColor: Color
    var text: String
    var textColor: Color = .white
    /// When set, the right wing shows a level bar (volume, brightness) instead of text.
    var progress: Double? = nil
}

@Observable
final class NotchViewModel {
    var state: NotchState = .closed
    /// Debug only: keep the current state regardless of the cursor.
    var pinned = false
    var notchSize: CGSize = CGSize(width: 200, height: 32)
    /// A live activity (e.g. music playing) widens the closed island around the notch.
    var hasLiveActivity = false
    /// Live activity needs room for text on the right wing (timer countdown).
    var wideLiveActivity = false
    /// Size of the expanded island, driven by what it currently shows.
    var expandedSize = CGSize(width: 440, height: 180)
    private(set) var alert: IslandAlert?
    private var alertTask: Task<Void, Never>?

    /// Width of each "wing" beside the physical notch.
    var wingWidth: CGFloat {
        // Kept tight so the island covers as few menu bar items as possible.
        guard let alert else { return notchSize.height + (wideLiveActivity ? 2 : -4) }
        return notchSize.height + (alert.progress != nil ? 36 : 2)
    }

    var closedSize: CGSize {
        let widened = hasLiveActivity || alert != nil
        return widened ? CGSize(width: notchSize.width + wingWidth * 2, height: notchSize.height) : notchSize
    }

    /// Slightly bigger island while hovering, before a click expands it.
    var peekSize: CGSize { CGSize(width: closedSize.width + 16, height: closedSize.height + 4) }

    /// Replaces the visible alert's content without restarting its timer.
    func update(_ alert: IslandAlert) {
        guard self.alert != nil else { return }
        self.alert = alert
    }

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
