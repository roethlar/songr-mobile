import XCTest
@testable import SongrKit

final class PlexSourceTests: XCTestCase {
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

    func testFetchArtistsFindsMusicSectionAndFollowsPaging() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { request in
            switch request.queryPairs["X-Plex-Container-Start"] {
            case "0": return .init(data: Fixtures.artistsPage1)
            default: return .init(data: Fixtures.artistsPage2)
            }
        }

        let artists = try await source.fetchArtists()
        XCTAssertEqual(artists.map(\.name), ["ABBA", "Éléphant", "The 1975"])

        let pages = StubURLProtocol.requests(matchingPath: "/library/sections/5/all")
        XCTAssertEqual(pages.count, 2, "totalSize 3 at page size 2 → 2 requests")
        XCTAssertEqual(pages.map { $0.queryPairs["X-Plex-Container-Start"] }, ["0", "2"])
        XCTAssertEqual(Set(pages.map { $0.queryPairs["type"] }), ["8"],
                       "artist listings are metadata type 8")
        XCTAssertEqual(pages.first?.value(forHTTPHeaderField: "X-Plex-Token"), "tok")
    }

    func testFetchAlbumsMapsArtistLinkageAndArtwork() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.albumsPage)
        }

        let albums = try await source.fetchAlbums()
        XCTAssertEqual(albums.count, 3)

        let arrival = try XCTUnwrap(albums.first { $0.id == "200" })
        XCTAssertEqual(arrival.artistID, "100")
        XCTAssertEqual(arrival.artistName, "ABBA")
        XCTAssertEqual(arrival.year, 1976)
        XCTAssertEqual(arrival.thumbPath, "/library/metadata/200/thumb/1")

        let notes = try XCTUnwrap(albums.first { $0.id == "202" })
        XCTAssertEqual(notes.thumbPath, "/library/metadata/102/thumb/1",
                       "falls back to parentThumb when the album has none")

        let request = StubURLProtocol.requests(matchingPath: "/library/sections/5/all").first
        XCTAssertEqual(request?.queryPairs["type"], "9",
                       "album listings are metadata type 9")
    }

    func testAlbumSortMetadataMapsPlexDatesAndCounts() async throws {
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.data("""
            {"MediaContainer":{"size":2,"totalSize":2,"Metadata":[
              {"ratingKey":"1","title":"Known","addedAt":1700000000,"lastViewedAt":1700000100,"viewCount":8},
              {"ratingKey":"2","title":"Unplayed","lastViewedAt":0}
            ]}}
            """))
        }
        let albums = try await source.fetchAlbums()
        XCTAssertEqual(albums[0].addedAt, Date(timeIntervalSince1970: 1700000000))
        XCTAssertEqual(albums[0].lastPlayedAt, Date(timeIntervalSince1970: 1700000100))
        XCTAssertEqual(albums[0].playCount, 8)
        XCTAssertNil(albums[1].addedAt)
        XCTAssertNil(albums[1].lastPlayedAt)
        XCTAssertNil(albums[1].playCount)
    }

    func testFetchTracksSortsByDiscThenTrackAndKeepsPartKey() async throws {
        StubURLProtocol.route("GET", "/library/metadata/200/children") { _ in
            .init(data: Fixtures.albumTracks)
        }

        let tracks = try await source.fetchTracks(albumID: "200")
        XCTAssertEqual(tracks.map(\.title),
                       ["Opener", "Closer of Disc One", "Second on Disc Two"])
        XCTAssertEqual(tracks.map(\.discNumber), [1, 1, 2])
        XCTAssertEqual(tracks.map(\.trackNumber), [1, 2, 2])
        XCTAssertEqual(tracks[0].playPath, "/library/parts/8300/1700000000/file.flac")
        XCTAssertEqual(tracks[0].durationMs, 215_000)
        XCTAssertEqual(tracks[0].albumID, "200")
    }

    func testStreamRequestUsesPartPathAndHeaderAuth() throws {
        let track = Track(id: "300", albumID: "200", title: "Opener",
                          trackNumber: 1, discNumber: 1, durationMs: 215_000,
                          playPath: "/library/parts/8300/1700000000/file.flac",
                          thumbPath: nil)
        let request = try source.streamRequest(for: track)
        XCTAssertEqual(request.url.absoluteString,
                       "https://pms.plex.direct:32400/library/parts/8300/1700000000/file.flac")
        XCTAssertEqual(request.headers["X-Plex-Token"], "tok")
        XCTAssertNil(request.url.query, "token rides in headers, never the URL")
    }

    func testArtworkRequestBuildsTranscodeURL() throws {
        let request = try source.artworkRequest(
            path: "/library/metadata/200/thumb/1", width: 300, height: 300
        )
        XCTAssertEqual(request.url.path, "/photo/:/transcode")
        let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?
            .queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        XCTAssertEqual(query?["width"], "300")
        XCTAssertEqual(query?["height"], "300")
        XCTAssertEqual(query?["minSize"], "1")
        XCTAssertEqual(query?["upscale"], "1")
        XCTAssertEqual(query?["url"], "/library/metadata/200/thumb/1")
        XCTAssertEqual(request.headers["X-Plex-Token"], "tok")
    }

    // MARK: Library choice (owner ruling: never silently pick when ambiguous)

    func testFetchMusicLibrariesListsEveryArtistSection() async throws {
        StubURLProtocol.route("GET", "/library/sections") { _ in
            .init(data: Fixtures.sectionsMultiMusic)
        }
        let libraries = try await source.fetchMusicLibraries()
        XCTAssertEqual(libraries, [
            MusicLibrary(id: "5", title: "Music"),
            MusicLibrary(id: "8", title: "Podcasts"),
            MusicLibrary(id: "9", title: "Audiobooks"),
        ])
    }

    func testAmbiguousMusicSectionsThrowWithCandidatesInsteadOfFirstPick() async {
        StubURLProtocol.route("GET", "/library/sections") { _ in
            .init(data: Fixtures.sectionsMultiMusic)
        }
        do {
            _ = try await source.fetchArtists()
            XCTFail("multiple artist sections must never auto-pick")
        } catch let LibrarySourceError.ambiguousMusicLibraries(libraries) {
            XCTAssertEqual(libraries.map(\.id), ["5", "8", "9"])
            XCTAssertEqual(libraries.map(\.title),
                           ["Music", "Podcasts", "Audiobooks"])
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testConfiguredSectionKeySkipsEnumerationAndScopesBrowse() async throws {
        // No /library/sections route beyond setUp's: a configured source must
        // not need it. Browse goes straight to the chosen section.
        let chosen = PlexSource(
            baseURL: URL(string: "https://pms.plex.direct:32400")!,
            identity: PlexClientIdentity(clientIdentifier: "songr-client-1"),
            token: "tok",
            sectionKey: "9",
            session: StubURLProtocol.makeSession(),
            pageSize: 200
        )
        StubURLProtocol.route("GET", "/library/sections/9/all") { _ in
            .init(data: Fixtures.data("""
            {"MediaContainer": {"size": 1, "totalSize": 1, "Metadata": [
              {"ratingKey": "500", "type": "artist", "title": "Ursula K. Le Guin"}
            ]}}
            """))
        }
        let artists = try await chosen.fetchArtists()
        XCTAssertEqual(artists.map(\.name), ["Ursula K. Le Guin"])
        XCTAssertTrue(StubURLProtocol.requests(matchingPath: "/library/sections").isEmpty,
                      "configured key must not trigger section enumeration")
    }

    func testSingleMusicSectionStillAutoResolves() async throws {
        // setUp's fixture has exactly one artist section (key 5): resolution
        // may auto-pick it without any user choice.
        StubURLProtocol.route("GET", "/library/sections/5/all") { _ in
            .init(data: Fixtures.data("""
            {"MediaContainer": {"size": 1, "totalSize": 1, "Metadata": [
              {"ratingKey": "100", "type": "artist", "title": "ABBA"}
            ]}}
            """))
        }
        let artists = try await source.fetchArtists()
        XCTAssertEqual(artists.map(\.name), ["ABBA"])
    }

    func testAuthStateReflectsToken() {
        XCTAssertEqual(source.authState, .signedIn)
        let signedOut = PlexSource(
            baseURL: URL(string: "https://pms.plex.direct:32400")!,
            identity: PlexClientIdentity(clientIdentifier: "songr-client-1"),
            token: ""
        )
        XCTAssertEqual(signedOut.authState, .signedOut)
        XCTAssertThrowsError(try signedOut.streamRequest(for: Track(
            id: "1", albumID: "1", title: "x", trackNumber: 1, discNumber: 1,
            durationMs: nil, playPath: "/p", thumbPath: nil
        )))
    }
}
