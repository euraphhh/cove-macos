import AppKit
import XCTest
@testable import Cove

final class ShelfTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("cove-shelf-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testIgnoresDuplicatesAndBlankText() {
        let shelf = ShelfModule(directory: directory)
        let url = URL(fileURLWithPath: "/etc/hosts")
        shelf.add([url, url])
        shelf.addText("   ")
        shelf.addLink(URL(string: "https://example.com")!)
        shelf.addLink(URL(string: "https://example.com")!)
        XCTAssertEqual(shelf.items.count, 2)
    }

    func testItemsSurviveARestart() {
        let first = ShelfModule(directory: directory)
        first.add([URL(fileURLWithPath: "/etc/hosts")])
        first.addText("hello")
        first.addLink(URL(string: "https://example.com/a")!)

        let second = ShelfModule(directory: directory)
        XCTAssertEqual(second.items.map(\.kind), first.items.map(\.kind))
    }

    func testMissingFilesAreDroppedOnLoad() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("temp.txt")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        let first = ShelfModule(directory: directory)
        first.add([file])
        first.addText("kept")
        try FileManager.default.removeItem(at: file)

        let second = ShelfModule(directory: directory)
        XCTAssertEqual(second.items.map(\.kind), [.text("kept")])
    }

    func testStoredImageIsDeletedWithItsItem() throws {
        let shelf = ShelfModule(directory: directory)
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        shelf.addImage(image)
        let item = try XCTUnwrap(shelf.items.first)
        let url = try XCTUnwrap(item.fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        shelf.remove(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(shelf.items.isEmpty)
    }

    func testClearEmptiesTheShelfOnDisk() {
        let shelf = ShelfModule(directory: directory)
        shelf.addText("one")
        shelf.clear()
        XCTAssertTrue(ShelfModule(directory: directory).items.isEmpty)
    }
}
