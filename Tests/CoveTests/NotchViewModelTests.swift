import XCTest
@testable import Cove

final class NotchViewModelTests: XCTestCase {
    func testClosedIslandWidensForLiveActivity() {
        let vm = NotchViewModel()
        XCTAssertEqual(vm.closedSize, vm.notchSize)
        vm.hasLiveActivity = true
        XCTAssertGreaterThan(vm.closedSize.width, vm.notchSize.width)
        XCTAssertEqual(vm.closedSize.height, vm.notchSize.height)
    }

    func testWideActivityGetsWiderWings() {
        let vm = NotchViewModel()
        vm.hasLiveActivity = true
        let narrow = vm.wingWidth
        vm.wideLiveActivity = true
        XCTAssertGreaterThan(vm.wingWidth, narrow)
    }

    func testPeekIsSlightlyBiggerThanClosed() {
        let vm = NotchViewModel()
        XCTAssertGreaterThan(vm.peekSize.width, vm.closedSize.width)
        XCTAssertGreaterThan(vm.peekSize.height, vm.closedSize.height)
    }
}
