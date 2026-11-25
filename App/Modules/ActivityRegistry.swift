import SwiftUI

/// Kind of live activity. A lower priority value wins the island.
struct Activity: Hashable, Comparable {
    let id: String
    let priority: Int

    static func < (a: Activity, b: Activity) -> Bool { a.priority < b.priority }

    static let timer = Activity(id: "timer", priority: 0)
    static let meeting = Activity(id: "meeting", priority: 1)
    static let download = Activity(id: "download", priority: 2)
    static let media = Activity(id: "media", priority: 3)
}

/// Everything the island needs to show one live activity, without knowing which module it comes from.
struct ActivityEntry {
    let activity: Activity
    /// The compact island needs room for text on the right wing (countdowns).
    var wide = false
    /// Height of the expanded content (below the notch).
    var expandedHeight: CGFloat = 58
    /// True while the activity should take over the island.
    let isLive: () -> Bool
    /// Left of the notch.
    let leading: () -> AnyView
    /// Right of the notch.
    let trailing: () -> AnyView
    /// Content of the detached bubble; receives the bubble's diameter.
    let bubble: (CGFloat) -> AnyView
    let expanded: () -> AnyView
}

/// A module that can own the island as a live activity.
protocol ActivityProviding {
    var activityEntry: ActivityEntry { get }
}

/// Holds the registered activities so the island view doesn't need to know each module.
/// To add an activity: make the module conform to `ActivityProviding` and register it in AppDelegate.
final class ActivityRegistry {
    private(set) var entries: [ActivityEntry] = []

    func register(_ provider: some ActivityProviding) {
        register(provider.activityEntry)
    }

    func register(_ entry: ActivityEntry) {
        entries.removeAll { $0.activity == entry.activity }
        entries.append(entry)
        entries.sort { $0.activity < $1.activity }
    }

    func entry(for activity: Activity?) -> ActivityEntry? {
        guard let activity else { return nil }
        return entries.first { $0.activity == activity }
    }

    /// Entries that are live right now, highest priority first.
    var live: [ActivityEntry] { entries.filter { $0.isLive() } }
}
