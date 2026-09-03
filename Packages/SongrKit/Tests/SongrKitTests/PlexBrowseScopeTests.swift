import XCTest
@testable import SongrKit

/// The extra browse scopes the phone UI surfaces (genres, playlists,
/// recently added / recently played / most played), fetched straight from
/// PMS. Request shapes and mappings are pinned here; no network leaves the
/// process (StubURLProtocol).
final class PlexBrowseScopeTests: XCTestCase {
    private var source: PlexSource!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        StubURLProtocol.route("GET", "/library/sections") { _ in
            .init(data: Fixtures.sections)
        }
        source = PlexSource(
            baseURL: URL(string: "https://pms.plex.direct:32400")!,
            identity: PlexClientIdentity(clientIdentifier: "songr-client-1"),
            token: "tok",
            session: StubURLProtocol.makeSession(),
            pageSize: 2
        )
    }

    // MARK: Genres

    func testFetchGenresListsAlbumGenreTags() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/genre") { _ in
            .init(data: Fixtures.genres)
        }
        let genres = try await source.fetchGenres()
        XCTAssertEqual(genres, [
            Genre(id: "190", title: "Rock"),
            Genre(id: "204", title: "Jazz"),
            Genre(id: "310", title: "Soul"),
        ])
        let request = StubURLProtocol
            .requests(matchingPath: "/library/sections/5/genre").first
        XCTAssertEqual(request?.queryPairs["type"], "9",
                       "genre tags keyed to albums so ids filter all?type=9")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "X-Plex-Token"), "tok")
    }

    func testFetchAlbumsInGenreFiltersTheAlbumIndex() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.albumsPage)
        }
        let albums = try await source.fetchAlbums(genreID: "190")
        XCTAssertEqual(albums.count, 3)
        let request = StubURLProtocol
            .requests(matchingPath: "/library/sections/5/all").first
        XCTAssertEqual(request?.queryPairs["type"], "9")
        XCTAssertEqual(request?.queryPairs["genre"], "190")
    }

    // MARK: Playlists

    func testFetchPlaylistsListsAudioPlaylistsWithCompositeArt() async throws {
        StubURLProtocol.route("GET", "/playlists") { _ in
            .init(data: Fixtures.playlists)
        }
        let playlists = try await source.fetchPlaylists()
        XCTAssertEqual(playlists, [
            Playlist(id: "900", title: "Road Trip", trackCount: 42,
                     durationMs: 5_400_000,
                     thumbPath: "/playlists/900/composite/1700000001"),
            Playlist(id: "901", title: "Quiet Morning", trackCount: 12,
                     durationMs: 1_800_000, thumbPath: nil),
        ])
        let request = StubURLProtocol.requests(matchingPath: "/playlists").first
        XCTAssertEqual(request?.queryPairs["playlistType"], "audio")
    }

    func testFetchPlaylistTracksKeepPlaylistOrderAndArtistCredit() async throws {
        StubURLProtocol.route("GET", "/playlists/900/items") { _ in
            .init(data: Fixtures.playlistItems)
        }
        let tracks = try await source.fetchPlaylistTracks(playlistID: "900")
        XCTAssertEqual(tracks.map(\.title), ["Dancing Queen", "Milestones"],
                       "playlist order is authoritative — a disc/track re-sort would reverse this fixture")
        XCTAssertEqual(tracks.map(\.artistName), ["ABBA", "Miles Davis"],
                       "cross-album rows carry the grandparent artist credit")
        XCTAssertEqual(tracks.map(\.albumID), ["200", "210"])
        XCTAssertEqual(tracks[0].playPath, "/library/parts/8300/1700000000/file.flac")
        XCTAssertEqual(tracks[1].thumbPath, "/library/metadata/210/thumb/1",
                       "parentThumb backfills a missing track thumb")
    }

    // MARK: Recency / play shelves

    func testRecentlyAddedAlbumsIsOneCappedAddedAtDescRequest() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.albumsPage)
        }
        let albums = try await source.fetchRecentlyAddedAlbums(limit: 60)
        XCTAssertEqual(albums.count, 3)
        let requests = StubURLProtocol.requests(matchingPath: "/library/sections/5/all")
        XCTAssertEqual(requests.count, 1,
                       "a shelf is one capped request, never the paging loop")
        let query = requests.first?.queryPairs
        XCTAssertEqual(query?["type"], "9")
        XCTAssertEqual(query?["sort"], "addedAt:desc")
        XCTAssertEqual(query?["X-Plex-Container-Size"], "60")
        XCTAssertNil(query?["viewCount>>"], "recently added includes unplayed albums")
    }

    func testRecentlyPlayedAlbumsFilterToPlayedSortedByLastViewed() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.playedAlbums)
        }
        let albums = try await source.fetchRecentlyPlayedAlbums(limit: 40)
        XCTAssertEqual(albums.map(\.title), ["Waterloo", "Arrival"],
                       "server sort order is kept verbatim")
        let query = StubURLProtocol
            .requests(matchingPath: "/library/sections/5/all").first?.queryPairs
        XCTAssertEqual(query?["sort"], "lastViewedAt:desc")
        XCTAssertEqual(query?["viewCount>>"], "0",
                       "played at least once — Plex's '>>' greater-than filter")
        XCTAssertEqual(query?["X-Plex-Container-Size"], "40")
    }

    func testMostPlayedAlbumsSortByViewCount() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.playedAlbums)
        }
        let albums = try await source.fetchMostPlayedAlbums(limit: 40)
        XCTAssertEqual(albums.map(\.title), ["Waterloo", "Arrival"])
        let query = StubURLProtocol
            .requests(matchingPath: "/library/sections/5/all").first?.queryPairs
        XCTAssertEqual(query?["sort"], "viewCount:desc")
        XCTAssertEqual(query?["viewCount>>"], "0")
    }
}
