import AppKit

/// Two-finger horizontal swipe over the island skips tracks (fingers left = next).
final class SwipeHandler {
    private weak var panel: NSPanel?
    private let viewModel: NotchViewModel
    private let media: MediaModule
    private var monitor: Any?
    private var accumulated: CGFloat = 0
    private var firedThisGesture = false
    private static let threshold: CGFloat = 45

    init(panel: NSPanel, viewModel: NotchViewModel, media: MediaModule) {
        self.panel = panel
        self.viewModel = viewModel
        self.media = media
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        // Trackpad gestures only; ignore the momentum tail after the fingers lift.
        guard event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return false }
        if event.phase.contains(.began) {
            accumulated = 0
            firedThisGesture = false
        }
        // Normalize to finger direction regardless of the "natural scrolling" setting.
        let finger = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) || abs(accumulated) > 0 else { return false }
        accumulated += finger

        if !firedThisGesture, abs(accumulated) > Self.threshold, media.nowPlaying != nil {
            firedThisGesture = true
            let next = accumulated < 0
            media.send(next ? "next track" : "previous track")
            viewModel.nudge(next ? -1 : 1)
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            accumulated = 0
        }
        return true
    }
}
