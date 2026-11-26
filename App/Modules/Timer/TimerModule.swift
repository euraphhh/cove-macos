import AppKit
import SwiftUI
import Observation

/// Countdown timer shown as a live activity, like the iPhone's Timer island.
@Observable
final class TimerModule: NotchModule {
    let id = "timer"
    private(set) var endDate: Date?
    private(set) var pausedRemaining: TimeInterval?
    private(set) var duration: TimeInterval = 0
    var onFinish: (() -> Void)?
    private var finishTimer: Timer?

    var isAvailable: Bool { endDate != nil || pausedRemaining != nil }
    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at date: Date = .now) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let endDate else { return 0 }
        return max(endDate.timeIntervalSince(date), 0)
    }

    func start(minutes: Double) {
        duration = minutes * 60
        pausedRemaining = nil
        schedule(endDate: Date().addingTimeInterval(duration))
    }

    func togglePause() {
        if let pausedRemaining {
            self.pausedRemaining = nil
            schedule(endDate: Date().addingTimeInterval(pausedRemaining))
        } else if endDate != nil {
            pausedRemaining = remaining()
            endDate = nil
            finishTimer?.invalidate()
        }
    }

    func cancel() {
        finishTimer?.invalidate()
        endDate = nil
        pausedRemaining = nil
    }

    private func schedule(endDate: Date) {
        self.endDate = endDate
        finishTimer?.invalidate()
        finishTimer = Timer.scheduledTimer(withTimeInterval: endDate.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            self?.cancel()
            NSSound(named: "Glass")?.play()
            self?.onFinish?()
        }
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    var compactView: some View { EmptyView() }
    var expandedView: some View { TimerExpandedView(timer: self) }
}

extension TimerModule: ActivityProviding {
    var activityEntry: ActivityEntry {
        ActivityEntry(
            activity: .timer, wide: true,
            isLive: { self.isAvailable },
            leading: {
                AnyView(Image(systemName: "timer").font(.system(size: 14, weight: .semibold)).foregroundStyle(.orange))
            },
            trailing: {
                AnyView(TimerCountdownText(timer: self, font: .system(size: 13, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.7))
            },
            bubble: { _ in AnyView(TimerBubble(timer: self)) },
            expanded: { AnyView(self.expandedView) })
    }
}

/// Ring that drains as the timer runs, shown in the detached bubble.
struct TimerBubble: View {
    let timer: TimerModule
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let left = timer.duration > 0 ? timer.remaining(at: ctx.date) / timer.duration : 0
            ZStack {
                Circle().stroke(.orange.opacity(0.25), lineWidth: 2.5)
                Circle().trim(from: 0, to: left).stroke(.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "timer").font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
            }
            .padding(7)
        }
    }
}

struct TimerCountdownText: View {
    let timer: TimerModule
    var font: Font
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            Text(TimerModule.format(timer.remaining(at: ctx.date)))
                .font(font.monospacedDigit())
                .foregroundStyle(.orange)
        }
    }
}

struct TimerExpandedView: View {
    let timer: TimerModule
    var body: some View {
        HStack(spacing: 14) {
            circleButton(timer.isPaused ? "play.fill" : "pause.fill", bg: .orange.opacity(0.3), fg: .orange) {
                timer.togglePause()
            }
            .accessibilityLabel(timer.isPaused ? Text("Resume timer") : Text("Pause timer"))
            circleButton("xmark", bg: .white.opacity(0.15), fg: .white) { timer.cancel() }
                .accessibilityLabel(Text("Cancel Timer"))
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("Timer").font(.caption).foregroundStyle(.orange)
                TimerCountdownText(timer: timer, font: .system(size: 40, weight: .light))
            }
        }
    }

    private func circleButton(_ icon: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                .foregroundStyle(fg).frame(width: 46, height: 46).background(Circle().fill(bg))
        }
        .buttonStyle(.plain)
    }
}
