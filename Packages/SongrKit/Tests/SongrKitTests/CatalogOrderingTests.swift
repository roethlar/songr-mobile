import XCTest
@testable import SongrKit

final class CatalogOrderingTests: XCTestCase {
    private func album(_ id: String, title: String, artist: String = "Artist",
                       year: Int? = nil, added: Double? = nil, played: Double? = nil,
                       plays: Int? = nil) -> Album {
        Album(id: id, title: title, artistID: "artist", artistName: artist,
              year: year, thumbPath: nil,
              addedAt: added.map(Date.init(timeIntervalSince1970:)),
              lastPlayedAt: played.map(Date.init(timeIntervalSince1970:)), playCount: plays)
    }

    func testAlbumMetadataSortsUseValuesAndKeepMissingLastInBothDirections() {
        let missing = album("missing", title: "A missing")
        let lower = album("lower", title: "Z lower", year: 1970, added: 100, played: 200, plays: 2)
        let higher = album("higher", title: "B higher", year: 2020, added: 300, played: 400, plays: 20)
        for field in [CatalogSortField.year, .dateAdded, .lastPlayed, .playCount] {
            XCTAssertEqual(CatalogOrdering.albums([missing, higher, lower], by: field, direction: .ascending)
                .map(\.id), ["lower", "higher", "missing"], "\(field)")
            XCTAssertEqual(CatalogOrdering.albums([missing, lower, higher], by: field, direction: .descending)
                .map(\.id), ["higher", "lower", "missing"], "\(field)")
        }
    }

    func testArtistAndTitleSortsAreDifferentAndTiesAreStable() {
        let items = [album("2", title: "Alpha", artist: "Zed"),
                     album("3", title: "Zulu", artist: "Éclair"),
                     album("1", title: "Alpha", artist: "Zed")]
        XCTAssertEqual(CatalogOrdering.albums(items, by: .name, direction: .ascending).map(\.id), ["1", "2", "3"])
        XCTAssertEqual(CatalogOrdering.albums(items, by: .artist, direction: .ascending).map(\.id), ["3", "1", "2"])
    }

    func testArtistsSortByAlbumCountAndJumpUsesDisplayedOrder() {
        let items = [Artist(id: "1", name: "Madonna", albumCount: 15, thumbPath: nil),
                     Artist(id: "2", name: "ABBA", albumCount: 1, thumbPath: nil),
                     Artist(id: "3", name: "Miles Davis", albumCount: 23, thumbPath: nil)]
        let sorted = CatalogOrdering.artists(items, by: .albumCount, direction: .descending)
        XCTAssertEqual(sorted.map(\.name), ["Miles Davis", "Madonna", "ABBA"])
        XCTAssertEqual(CatalogOrdering.firstLetterIndices(sorted, name: \.name), ["M": 0, "A": 2])
    }

    func testDescendingAlphabetIndexRetainsHashLastAndEveryItem() {
        let items = [album("1", title: "3 Songs"), album("2", title: "Alpha"), album("3", title: "Zulu")]
        let sorted = CatalogOrdering.albums(items, by: .name, direction: .descending)
        let sections = CatalogOrdering.alphabeticalSections(sorted, name: \.title, direction: .descending)
        XCTAssertEqual(sections.map(\.title), ["Z", "A", "#"])
        XCTAssertEqual(sections.flatMap(\.items).map(\.id), ["3", "2", "1"])
    }

    func testOldAlbumSnapshotStillDecodesWithoutNewFields() throws {
        let data = Data(#"{"id":"old","title":"Arrival","artistID":"abba","artistName":"ABBA","year":1976}"#.utf8)
        let old = try JSONDecoder().decode(Album.self, from: data)
        XCTAssertNil(old.addedAt)
        XCTAssertNil(old.lastPlayedAt)
        XCTAssertNil(old.playCount)
    }
}
