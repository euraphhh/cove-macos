import SwiftUI
import XCTest
@testable import Cove

final class ActivityRegistryTests: XCTestCase {
    private func entry(_ activity: Activity, live: Bool) -> ActivityEntry {
        ActivityEntry(activity: activity, isLive: { live },
                      leading: { AnyView(EmptyView()) }, trailing: { AnyView(EmptyView()) },
                      bubble: { _ in AnyView(EmptyView()) }, expanded: { AnyView(EmptyView()) })
    }

    func testLiveEntriesFollowPriorityNotRegistrationOrder() {
        let registry = ActivityRegistry()
        registry.register(entry(.media, live: true))
        registry.register(entry(.download, live: false))
        registry.register(entry(.timer, live: true))
        XCTAssertEqual(registry.live.map(\.activity), [.timer, .media])
    }

    func testRegisteringTwiceReplaces() {
        let registry = ActivityRegistry()
        registry.register(entry(.timer, live: false))
        registry.register(entry(.timer, live: true))
        XCTAssertEqual(registry.entries.count, 1)
        XCTAssertEqual(registry.live.count, 1)
    }

    func testLookup() {
        let registry = ActivityRegistry()
        registry.register(entry(.meeting, live: true))
        XCTAssertNotNil(registry.entry(for: .meeting))
        XCTAssertNil(registry.entry(for: .download))
        XCTAssertNil(registry.entry(for: nil))
    }

    func testTimerModuleProvidesItsEntry() {
        let timer = TimerModule()
        let registry = ActivityRegistry()
        registry.register(timer)
        XCTAssertTrue(registry.live.isEmpty)
        timer.start(minutes: 1)
        XCTAssertEqual(registry.live.map(\.activity), [.timer])
        XCTAssertTrue(registry.live.first?.wide ?? false)
        timer.cancel()
    }
}
