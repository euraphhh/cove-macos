import AppKit
import EventKit
import SwiftUI
import Observation

struct Meeting: Equatable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var color: Color
    var joinURL: URL?
}

/// Next meeting as a live activity. Opt-in; Calendar access is requested only when enabled.
@Observable
final class CalendarModule: NotchModule {
    let id = "calendar"
    static let defaultsKey = "calendarEnabled"
    /// Show the live activity this long before a meeting starts (and briefly after).
    static let leadTime: TimeInterval = 10 * 60
    static let graceAfterStart: TimeInterval = 5 * 60

    private(set) var next: Meeting?
    /// Remaining events today, for the island's home view.
    private(set) var today: [Meeting] = []
    var onStart: ((Meeting) -> Void)?
    private let store = EKEventStore()
    private var timer: Timer?
    private var announcedID: String?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.defaultsKey) }

    /// Meeting close enough to take over the island.
    var isAvailable: Bool {
        guard let next else { return false }
        let now = Date()
        return next.start.timeIntervalSince(now) <= Self.leadTime && now.timeIntervalSince(next.start) <= Self.graceAfterStart
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)
        enabled ? start() : stop()
    }

    func start() {
        guard isEnabled, timer == nil else { return }
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard granted, let self else { return }
                self.refresh()
                self.timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.refresh() }
                NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: self.store, queue: .main) { [weak self] _ in
                    self?.refresh()
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        next = nil
    }

    func refresh() {
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-Self.graceAfterStart),
                                                 end: now.addingTimeInterval(12 * 3600), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled && !Self.declined($0) }
            .filter { $0.startDate.addingTimeInterval(Self.graceAfterStart) > now }
            .sorted { $0.startDate < $1.startDate }
        let meetings = events.map {
            Meeting(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Meeting",
                    start: $0.startDate, end: $0.endDate,
                    color: Color(nsColor: $0.calendar?.color ?? .systemBlue),
                    joinURL: Self.joinURL(in: $0))
        }
        let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)
        let todays = Array(meetings.filter { $0.start < endOfDay }.prefix(3))
        if todays != today { today = todays }
        set(meetings.first)
    }

    /// Used by refresh and by the debug hook.
    func set(_ meeting: Meeting?) {
        if meeting != next { next = meeting }
        if let m = meeting, m.start <= Date(), announcedID != m.id, Date().timeIntervalSince(m.start) < 60 {
            announcedID = m.id
            onStart?(m)
        }
    }

    func join() {
        guard let url = next?.joinURL else { return }
        NSWorkspace.shared.open(url)
    }

    private static func declined(_ event: EKEvent) -> Bool {
        event.attendees?.first { $0.isCurrentUser }?.participantStatus == .declined
    }

    private static let joinPattern = try? NSRegularExpression(
        pattern: #"https://(meet\.google\.com/[a-z\-]+|[\w.-]*zoom\.us/[^\s<>"]+|teams\.microsoft\.com/[^\s<>"]+|teams\.live\.com/[^\s<>"]+|[\w.-]*webex\.com/[^\s<>"]+)"#,
        options: .caseInsensitive)

    private static func joinURL(in event: EKEvent) -> URL? {
        let text = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        guard let regex = joinPattern,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return URL(string: String(text[range]))
    }

    static func countdown(to date: Date, from now: Date = .now) -> String {
        let s = date.timeIntervalSince(now)
        if s <= 0 { return "Now" }
        let m = Int((s / 60).rounded(.up))
        return m >= 60 ? "\(m / 60)h" : "\(m)m"
    }

    var compactView: some View { EmptyView() }
    var expandedView: some View { MeetingExpandedView(calendar: self) }
}

struct MeetingCountdownText: View {
    let meeting: Meeting
    var font: Font
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { ctx in
            Text(CalendarModule.countdown(to: meeting.start, from: ctx.date))
                .font(font.monospacedDigit())
                .foregroundStyle(meeting.color)
        }
    }
}

struct MeetingExpandedView: View {
    let calendar: CalendarModule

    var body: some View {
        if let m = calendar.next {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 2).fill(m.color).frame(width: 4, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("\(m.start.formatted(date: .omitted, time: .shortened)) – \(m.end.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(.white.opacity(0.55))
                        Text("·").foregroundStyle(.white.opacity(0.3))
                        MeetingCountdownText(meeting: m, font: .system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 13))
                }
                Spacer(minLength: 8)
                if m.joinURL != nil {
                    Button(action: calendar.join) {
                        Label("Join", systemImage: "video.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(height: 36)
                            .background(Capsule().fill(Color.green))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
            .foregroundStyle(.white)
        }
    }
}
