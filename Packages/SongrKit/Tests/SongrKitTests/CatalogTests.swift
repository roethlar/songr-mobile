import XCTest
@testable import SongrKit

final class CatalogTests: XCTestCase {
    private func artist(_ id: String, _ name: String, count: Int = 0) -> Artist {
        Artist(id: id, name: name, albumCount: count, thumbPath: nil)
    }

    private func album(_ id: String, _ title: String, artistID: String,
                       year: Int? = nil) -> Album {
        Album(id: id, title: title, artistID: artistID, artistName: "a",
              year: year, thumbPath: nil)
    }

    // MARK: Sectioning

    func testSectionTitleFoldsDiacriticsAndCase() {
        XCTAssertEqual(CatalogIndexer.sectionTitle(for: "Éléphant"), "E")
        XCTAssertEqual(CatalogIndexer.sectionTitle(for: "abba"), "A")
        XCTAssertEqual(CatalogIndexer.sectionTitle(for: "Ólafur Arnalds"), "O")
    }

    func testNonLettersLandInHashSection() {
        XCTAssertEqual(CatalogIndexer.sectionTitle(for: "1975"), "#")
        XCTAssertEqual(CatalogIndexer.sectionTitle(for: "!!!"), "#")
        XCTAssertEqual(CatalogIndexer.sectionTitle(for: ""), "#")
    }

    func testSectionsSortAlphabeticallyWithHashLastAndEmptyLettersDropped() {
        let artists = [
            artist("1", "Zebra"), artist("2", "Éléphant"), artist("3", "1975"),
            artist("4", "abba"), artist("5", "ABC"),
        ]
        let sections = CatalogIndexer.sections(of: artists, name: \.name)
        XCTAssertEqual(sections.map(\.title), ["A", "E", "Z", "#"],
                       "only non-empty letters, # after Z")
        XCTAssertEqual(sections[0].items.map(\.name), ["abba", "ABC"],
                       "case-insensitive ordering inside a section")
    }

    func testFullAlphabetOrderMatchesContactsStyle() {
        XCTAssertEqual(CatalogIndexer.sectionTitles.count, 27)
        XCTAssertEqual(CatalogIndexer.sectionTitles.first, "A")
        XCTAssertEqual(CatalogIndexer.sectionTitles.last, "#")
    }

    // MARK: Album counts

    func testSnapshotRecomputesAlbumCountsFromAlbumIndex() {
        let snapshot = CatalogSnapshot.build(
            artists: [artist("100", "ABBA", count: 99), artist("102", "The 1975")],
            albums: [
                album("200", "Arrival", artistID: "100"),
                album("201", "Waterloo", artistID: "100"),
                album("202", "Notes", artistID: "102"),
            ]
        )
        XCTAssertEqual(snapshot.artists.first { $0.id == "100" }?.albumCount, 2,
                       "album index wins over the server-reported count")
        XCTAssertEqual(snapshot.artists.first { $0.id == "102" }?.albumCount, 1)
    }

    func testSnapshotKeepsServerCountWhenArtistHasNoAlbumsInIndex() {
        let snapshot = CatalogSnapshot.build(
            artists: [artist("7", "Compilation-Only", count: 3)],
            albums: []
        )
        XCTAssertEqual(snapshot.artists.first?.albumCount, 3)
    }

    func testAlbumsForArtistSortOldestFirstThenTitle() {
        let snapshot = CatalogSnapshot.build(
            artists: [artist("100", "ABBA")],
            albums: [
                album("1", "Voyage", artistID: "100", year: 2021),
                album("2", "Arrival", artistID: "100", year: 1976),
                album("3", "Undated B", artistID: "100"),
                album("4", "Undated A", artistID: "100"),
                album("5", "Other Artist", artistID: "999", year: 1970),
            ]
        )
        XCTAssertEqual(snapshot.albums(forArtist: "100").map(\.title),
                       ["Arrival", "Voyage", "Undated A", "Undated B"],
                       "year ascending, undated last, ties by title")
    }

    // MARK: Store persistence

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("songr-tests-\(UUID().uuidString)")
    }

    func testStoreRoundTripsSnapshot() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CatalogStore(directory: directory)

        let snapshot = CatalogSnapshot.build(
            generatedAt: Date(timeIntervalSince1970: 1_756_500_000),
            artists: [artist("100", "ABBA")],
            albums: [album("200", "Arrival", artistID: "100", year: 1976)]
        )
        try await store.persist(snapshot)
        let loaded = await store.loadCached()
        XCTAssertEqual(loaded, snapshot)
    }

    func testStoreReturnsNilForMissingOrCorruptCache() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CatalogStore(directory: directory)

        let empty = await store.loadCached()
        XCTAssertNil(empty)

        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("catalog.json"))
        let corrupt = await store.loadCached()
        XCTAssertNil(corrupt)
    }

    func testRefreshFetchesBothIndexesAndPersists() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CatalogStore(directory: directory)

        StubURLProtocol.reset()
        StubURLProtocol.route("GET", "/library/sections") { _ in
            .init(data: Fixtures.sections)
        }
        StubURLProtocol.route("GET", "/library/sections/5/all") { request in
            switch request.queryPairs["type"] {
            case "8":
                return .init(data: request.queryPairs["X-Plex-Container-Start"] == "0"
                    ? Fixtures.artistsPage1 : Fixtures.artistsPage2)
            default:
                return .init(data: Fixtures.albumsPage)
            }
        }
        let source = PlexSource(
            baseURL: URL(string: "https://pms.plex.direct:32400")!,
            identity: PlexClientIdentity(clientIdentifier: "songr-client-1"),
            token: "tok",
            session: StubURLProtocol.makeSession(),
            pageSize: 2
        )

        // Whole-second date: ISO8601 persistence drops sub-second precision.
        let snapshot = try await store.refresh(
            from: source, now: Date(timeIntervalSince1970: 1_756_500_000)
        )
        XCTAssertEqual(snapshot.artists.count, 3)
        XCTAssertEqual(snapshot.albums.count, 3)
        XCTAssertEqual(snapshot.artists.first { $0.id == "100" }?.albumCount, 2,
                       "counts recomputed during refresh")
        let reloaded = await store.loadCached()
        XCTAssertEqual(reloaded, snapshot, "refresh persists the snapshot")
    }
}
