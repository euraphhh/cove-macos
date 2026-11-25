import XCTest
@testable import Cove

final class TimerModuleTests: XCTestCase {
    func testFormatsMinutesAndSeconds() {
        XCTAssertEqual(TimerModule.format(65), "1:05")
        XCTAssertEqual(TimerModule.format(300), "5:00")
    }

    func testFormatsHours() {
        XCTAssertEqual(TimerModule.format(3725), "1:02:05")
    }

    func testRoundsPartialSecondsUp() {
        XCTAssertEqual(TimerModule.format(0.2), "0:01")
    }

    func testPauseKeepsRemainingTime() {
        let timer = TimerModule()
        XCTAssertFalse(timer.isAvailable)
        timer.start(minutes: 1)
        XCTAssertTrue(timer.isAvailable)
        timer.togglePause()
        XCTAssertTrue(timer.isPaused)
        XCTAssertEqual(timer.remaining(), 60, accuracy: 1)
        timer.togglePause()
        XCTAssertFalse(timer.isPaused)
        timer.cancel()
        XCTAssertFalse(timer.isAvailable)
    }
}
