import XCTest
@testable import SongrKit

final class PlaybackQueueTests: XCTestCase {
    private func track(_ number: Int) -> Track {
        Track(id: "t\(number)", albumID: "200", title: "Track \(number)",
              trackNumber: number, discNumber: 1, durationMs: 1000,
              playPath: "/library/parts/\(number)/file.flac", thumbPath: nil)
    }

    private var album: [Track] { (1...5).map(track) }

    func testEmptyTracklistYieldsNoQueue() {
        XCTAssertNil(PlaybackQueue(tracks: [], startIndex: 0))
    }

    func testPlayFromTappedTrackSlicesToAlbumEnd() throws {
        let queue = try XCTUnwrap(PlaybackQueue(tracks: album, startIndex: 2))
        XCTAssertEqual(queue.current.id, "t3", "tapped track plays first")
        XCTAssertEqual(queue.playbackSlice.map(\.id), ["t3", "t4", "t5"],
                       "queue is tapped track through album end")
        XCTAssertEqual(queue.upcoming.map(\.id), ["t4", "t5"])
        XCTAssertTrue(queue.hasPrevious, "earlier album tracks stay reachable")
    }

    func testStartIndexIsClampedIntoRange() throws {
        let past = try XCTUnwrap(PlaybackQueue(tracks: album, startIndex: 99))
        XCTAssertEqual(past.current.id, "t5")
        let negative = try XCTUnwrap(PlaybackQueue(tracks: album, startIndex: -1))
        XCTAssertEqual(negative.current.id, "t1")
    }

    func testAdvanceWalksToEndThenRefuses() throws {
        var queue = try XCTUnwrap(PlaybackQueue(tracks: album, startIndex: 3))
        XCTAssertTrue(queue.advance())
        XCTAssertEqual(queue.current.id, "t5")
        XCTAssertFalse(queue.hasNext)
        XCTAssertFalse(queue.advance(), "no wrap-around past the album")
        XCTAssertEqual(queue.current.id, "t5")
    }

    func testGoToPreviousWalksBackThenRefuses() throws {
        var queue = try XCTUnwrap(PlaybackQueue(tracks: album, startIndex: 1))
        XCTAssertTrue(queue.goToPrevious())
        XCTAssertEqual(queue.current.id, "t1")
        XCTAssertFalse(queue.goToPrevious(),
                       "engine restarts the first track instead")
    }

    func testJumpClampsAndMoves() throws {
        var queue = try XCTUnwrap(PlaybackQueue(tracks: album, startIndex: 0))
        queue.jump(to: 4)
        XCTAssertEqual(queue.current.id, "t5")
        queue.jump(to: -3)
        XCTAssertEqual(queue.current.id, "t1")
    }
}
