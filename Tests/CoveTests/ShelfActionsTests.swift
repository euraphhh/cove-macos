import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Cove

final class ShelfActionsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("cove-actions-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func item(_ kind: ShelfItem.Kind) -> ShelfItem { ShelfItem(kind: kind) }

    private func writePNG(named name: String) throws -> URL {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.blue.setFill()
            rect.fill()
            return true
        }
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let png = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        let url = directory.appendingPathComponent(name)
        try png.write(to: url)
        return url
    }

    func testActionsDependOnTheKindOfItem() {
        XCTAssertEqual(ShelfActions.available(for: item(.file(URL(fileURLWithPath: "/tmp/a.png")))),
                       [.copyText, .convertJPEG, .compress, .airDrop])
        XCTAssertEqual(ShelfActions.available(for: item(.file(URL(fileURLWithPath: "/tmp/a.heic")))),
                       [.copyText, .convertPNG, .convertJPEG, .compress, .airDrop])
        XCTAssertEqual(ShelfActions.available(for: item(.file(URL(fileURLWithPath: "/tmp/a.jpg")))),
                       [.copyText, .convertPNG, .compress, .airDrop])
        XCTAssertEqual(ShelfActions.available(for: item(.file(URL(fileURLWithPath: "/tmp/a.txt")))),
                       [.compress, .airDrop])
        XCTAssertEqual(ShelfActions.available(for: item(.link(URL(string: "https://example.com")!))), [.airDrop])
        XCTAssertEqual(ShelfActions.available(for: item(.text("hi"))), [.airDrop])
    }

    func testConvertsPNGToJPEG() throws {
        let png = try writePNG(named: "photo.png")
        let output = directory.appendingPathComponent("out")
        let jpeg = try ShelfActions.convertImage(at: png, to: .jpeg, in: output)
        XCTAssertEqual(jpeg.pathExtension, "jpeg")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(jpeg as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
    }

    func testConvertingAnUnreadableFileFails() throws {
        let text = directory.appendingPathComponent("note.txt")
        try "not an image".write(to: text, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ShelfActions.convertImage(at: text, to: .png, in: directory))
    }

    func testZipCreatesAnArchive() throws {
        let file = directory.appendingPathComponent("report.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        let output = directory.appendingPathComponent("out")
        let zip = try ShelfActions.zip(file, in: output)
        XCTAssertEqual(zip.lastPathComponent, "report.zip")
        let size = try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    func testUniqueURLAvoidsOverwriting() throws {
        let first = ShelfActions.uniqueURL(name: "a", ext: "zip", in: directory)
        XCTAssertEqual(first.lastPathComponent, "a.zip")
        try Data().write(to: first)
        XCTAssertEqual(ShelfActions.uniqueURL(name: "a", ext: "zip", in: directory).lastPathComponent, "a 2.zip")
    }

    func testPerformAddsTheResultToTheShelf() throws {
        let file = directory.appendingPathComponent("doc.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        let shelf = ShelfModule(directory: directory.appendingPathComponent("shelf"))
        shelf.add([file])
        let done = expectation(description: "feedback")
        shelf.onFeedback = { _, text in
            XCTAssertEqual(text, "Done")
            done.fulfill()
        }
        shelf.perform(.compress, on: try XCTUnwrap(shelf.items.first))
        wait(for: [done], timeout: 10)
        XCTAssertEqual(shelf.items.count, 2)
        XCTAssertTrue(shelf.working.isEmpty)
    }
}
