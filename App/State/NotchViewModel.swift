import SwiftUI
import Observation

enum NotchState { case closed, peek, expanded }

@Observable
final class NotchViewModel {
    var state: NotchState = .closed
    var notchSize: CGSize = CGSize(width: 200, height: 32)
    /// A live activity (e.g. music playing) widens the closed island around the notch.
    var hasLiveActivity = false

    /// Width of each "wing" beside the physical notch in the compact live activity.
    var wingWidth: CGFloat { notchSize.height + 6 }

    var closedSize: CGSize {
        hasLiveActivity
            ? CGSize(width: notchSize.width + wingWidth * 2, height: notchSize.height)
            : notchSize
    }
}
