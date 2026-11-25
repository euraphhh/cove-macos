import XCTest
@testable import Cove

final class CalendarTests: XCTestCase {
    func testCountdown() {
        let now = Date()
        XCTAssertEqual(CalendarModule.countdown(to: now, from: now), "Now")
        XCTAssertEqual(CalendarModule.countdown(to: now.addingTimeInterval(90), from: now), "2m")
        XCTAssertEqual(CalendarModule.countdown(to: now.addingTimeInterval(2 * 3600), from: now), "2h")
    }

    func testFindsJoinLinks() {
        XCTAssertEqual(CalendarModule.joinURL(in: "Call: https://meet.google.com/abc-defg-hij thanks")?.host, "meet.google.com")
        XCTAssertEqual(CalendarModule.joinURL(in: "https://us02web.zoom.us/j/123?pwd=x")?.host, "us02web.zoom.us")
        XCTAssertNil(CalendarModule.joinURL(in: "Room 4B, no link"))
    }
}
