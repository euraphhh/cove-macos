import XCTest
@testable import Cove

final class MediaTests: XCTestCase {
    func testParsesSpotifyReply() throws {
        let np = try XCTUnwrap(NowPlaying.parse("Song||Artist||playing||12,5||200.0||https://i.scdn.co/image/abc", player: .spotify))
        XCTAssertEqual(np.title, "Song")
        XCTAssertEqual(np.artist, "Artist")
        XCTAssertTrue(np.isPlaying)
        XCTAssertEqual(np.position, 12.5, accuracy: 0.001)
        XCTAssertEqual(np.duration, 200, accuracy: 0.001)
        XCTAssertEqual(np.artworkURL?.host, "i.scdn.co")
    }

    func testParsesMusicReplyWithoutArtworkURL() throws {
        let np = try XCTUnwrap(NowPlaying.parse("Song||Artist||paused||3||180||", player: .music))
        XCTAssertFalse(np.isPlaying)
        XCTAssertNil(np.artworkURL)
    }

    func testRejectsIncompleteReply() {
        XCTAssertNil(NowPlaying.parse("Song||Artist", player: .music))
    }

    func testElapsedAdvancesOnlyWhilePlaying() throws {
        let start = Date()
        var np = try XCTUnwrap(NowPlaying.parse("S||A||playing||10||100||", player: .music, sampledAt: start))
        XCTAssertEqual(np.elapsed(at: start.addingTimeInterval(5)), 15, accuracy: 0.001)
        XCTAssertEqual(np.elapsed(at: start.addingTimeInterval(500)), 100, accuracy: 0.001) // capped at duration
        np.isPlaying = false
        XCTAssertEqual(np.elapsed(at: start.addingTimeInterval(5)), 10, accuracy: 0.001)
    }
}
