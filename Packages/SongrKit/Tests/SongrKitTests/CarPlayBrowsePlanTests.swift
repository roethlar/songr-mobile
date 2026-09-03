import XCTest
@testable import SongrKit

final class CarPlayBrowsePlanTests: XCTestCase {
    private func artist(_ id: String, _ name: String, count: Int = 1) -> Artist {
        Artist(id: id, name: name, albumCount: count, thumbPath: nil)
    }

    private func albums(_ titles: [String]) -> [Album] {
        titles.enumerated().map { index, title in
            Album(id: "a\(index)", title: title, artistID: "100",
                  artistName: "ABBA", year: nil, thumbPath: nil)
        }
    }

    // MARK: Artists list plan

    func testArtistSectionsCarryIndexTitlesInRailOrder() {
        let sections = CarPlayBrowsePlan.artistSections([
            artist("1", "Zebra"), artist("2", "abba"),
            artist("3", "1975"), artist("4", "Émile"),
        ])
        XCTAssertEqual(CarPlayBrowsePlan.indexTitles(for: sections),
                       ["A", "E", "Z", "#"],
                       "sectionIndexTitle rail: letters present, # last")
        XCTAssertEqual(sections.first?.artists.map(\.name), ["abba"])
    }

    func testArtistDetailTextPluralizesAlbumCount() {
        XCTAssertEqual(CarPlayBrowsePlan.artistDetailText(albumCount: 1), "1 album")
        XCTAssertEqual(CarPlayBrowsePlan.artistDetailText(albumCount: 12), "12 albums")
        XCTAssertEqual(CarPlayBrowsePlan.artistDetailText(albumCount: 0), "0 albums")
    }

    // MARK: Image-row batching

    func testImageRowBatchesSplitAtBatchSizeWithRemainder() {
        let batches = CarPlayBrowsePlan.imageRowBatches(
            albums(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]),
            batchSize: 4
        )
        XCTAssertEqual(batches.map(\.count), [4, 4, 2],
                       "full rows then the remainder row")
        XCTAssertEqual(batches[2].map(\.title), ["I", "J"])
    }

    func testImageRowBatchesEdgeCases() {
        XCTAssertEqual(CarPlayBrowsePlan.imageRowBatches([], batchSize: 8), [])
        XCTAssertEqual(CarPlayBrowsePlan.imageRowBatches(albums(["A"]), batchSize: 0), [],
                       "a zero batch size must not trap")
        XCTAssertEqual(
            CarPlayBrowsePlan.imageRowBatches(albums(["A", "B"]), batchSize: 8).map(\.count),
            [2], "under one row stays one row"
        )
    }

    // MARK: Albums tab plan

    func testAlbumSectionsGroupByLetterAndBatchWithinSection() {
        let sections = CarPlayBrowsePlan.albumSections(
            albums(["Arrival", "Abbey Road", "Aja", "Blue", "1989"]),
            batchSize: 2
        )
        XCTAssertEqual(sections.map(\.indexTitle), ["A", "B", "#"])
        XCTAssertEqual(sections[0].rows.map(\.count), [2, 1],
                       "three A-albums batch as 2 + 1 at batch size 2")
        XCTAssertEqual(sections[0].rows[0].map(\.title), ["Abbey Road", "Aja"])
        XCTAssertEqual(sections[2].rows.map { $0.map(\.title) }, [["1989"]])
    }

    func testAlbumSectionsRespectRowBudget() {
        // 5 letters × 1 row each, budget 3 → first three lettered sections.
        let sections = CarPlayBrowsePlan.albumSections(
            albums(["Alpha", "Bravo", "Charlie", "Delta", "Echo"]),
            batchSize: 8,
            maximumRows: 3
        )
        XCTAssertEqual(sections.map(\.indexTitle), ["A", "B", "C"],
                       "row budget caps the template item count")
        XCTAssertEqual(sections.flatMap(\.rows).count, 3)
    }

    func testAlbumSectionsBudgetCanSplitTheOverflowingSection() {
        let sections = CarPlayBrowsePlan.albumSections(
            albums(["A1", "A2", "A3", "A4"]),
            batchSize: 1,
            maximumRows: 2
        )
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].rows.count, 2,
                       "the overflowing letter keeps its first rows only")
    }
}
