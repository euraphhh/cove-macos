import XCTest
@testable import Cove

final class DownloadTests: XCTestCase {
    func testStripsPartialSuffixes() {
        let dir = URL(fileURLWithPath: "/tmp")
        XCTAssertEqual(DownloadModule.displayName(dir.appendingPathComponent("a.zip.crdownload")), "a.zip")
        XCTAssertEqual(DownloadModule.displayName(dir.appendingPathComponent("b.dmg.download")), "b.dmg")
        XCTAssertEqual(DownloadModule.displayName(dir.appendingPathComponent("c.iso.part")), "c.iso")
        XCTAssertEqual(DownloadModule.displayName(dir.appendingPathComponent("plain.txt")), "plain.txt")
    }
}
