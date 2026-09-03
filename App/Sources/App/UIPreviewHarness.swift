#if DEBUG
import Foundation
import SongrKit

/// Debug-only screenshot harness: `-SongrUIPreview` fills the app with a
/// fixture catalog served by an offline LibrarySource so the browse/now-playing
/// layouts can be verified on a simulator without a live Plex link. Never
/// compiled into release builds; never triggered without the launch argument.
///
/// Extra arguments:
///   -SongrPreviewScope albums     start on the Albums scope
///   -SongrPreviewNowPlaying       start playback + open the now-playing sheet
///   -SongrPreviewLibraryPicker    show the multi-library picker phase
///   -SongrForceLandscape          (PhoneSceneDelegate) force landscape
@MainActor
enum UIPreviewHarness {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-SongrUIPreview")
    }

    static func flag(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(name)
    }

    static func value(after name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name),
              args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static func apply(to model: AppModel) {
        let source = PreviewLibrarySource()
        if flag("-SongrPreviewLibraryPicker") {
            model.previewInstall(source: source, snapshot: snapshot)
            model.previewShowLibraryPicker([
                MusicLibrary(id: "5", title: "Music"),
                MusicLibrary(id: "8", title: "Podcasts"),
                MusicLibrary(id: "9", title: "Audiobooks"),
            ])
            return
        }
        model.previewInstall(source: source, snapshot: snapshot)
        if flag("-SongrPreviewNowPlaying") {
            let album = snapshot.albums.first { $0.title == "Rumours" }!
            let tracks = PreviewLibrarySource.rumoursTracks
            model.play(album: album, tracks: tracks, startAt: 2)
            model.player.togglePlayPause()  // freeze at 0:00 for the screenshot
        }
    }

    static let snapshot: CatalogSnapshot = {
        CatalogSnapshot.build(artists: PreviewLibrarySource.artists,
                              albums: PreviewLibrarySource.albums)
    }()
}

/// Offline source: fixture data in, monogram artwork out (artwork and
/// stream requests both fail on purpose — tiles show the songr mono-tile
/// placeholder, and playback state freezes on the requested track).
struct PreviewLibrarySource: LibrarySource {
    var authState: AuthState { .signedIn }

    func fetchMusicLibraries() async throws -> [MusicLibrary] {
        [MusicLibrary(id: "5", title: "Music"),
         MusicLibrary(id: "8", title: "Podcasts"),
         MusicLibrary(id: "9", title: "Audiobooks")]
    }

    func fetchArtists() async throws -> [Artist] { Self.artists }
    func fetchAlbums() async throws -> [Album] { Self.albums }

    func fetchGenres() async throws -> [Genre] { Self.genres }

    /// Deterministic thirds of the album fixture stand in for genre filters.
    func fetchAlbums(genreID: String) async throws -> [Album] {
        let bucket = (Int(genreID) ?? 0) % 3
        return Self.albums.enumerated()
            .filter { $0.offset % 3 == bucket }
            .map(\.element)
    }

    func fetchPlaylists() async throws -> [Playlist] { Self.playlists }

    func fetchPlaylistTracks(playlistID: String) async throws -> [Track] {
        Self.rumoursTracks.enumerated().map { index, track in
            Track(id: "pl-\(playlistID)-\(track.id)", albumID: track.albumID,
                  title: track.title, trackNumber: track.trackNumber,
                  discNumber: track.discNumber, durationMs: track.durationMs,
                  playPath: track.playPath, thumbPath: track.thumbPath,
                  artistName: index % 2 == 0 ? "Fleetwood Mac" : "Various Artists")
        }
    }

    func fetchRecentlyAddedAlbums(limit: Int) async throws -> [Album] {
        Array(Self.albums.reversed().prefix(limit))
    }

    func fetchRecentlyPlayedAlbums(limit: Int) async throws -> [Album] {
        Array(Self.albums.enumerated()
            .filter { $0.offset % 2 == 0 }
            .map(\.element)
            .prefix(limit))
    }

    func fetchMostPlayedAlbums(limit: Int) async throws -> [Album] {
        Array(Self.albums.enumerated()
            .filter { $0.offset % 2 == 1 }
            .map(\.element)
            .prefix(limit))
    }

    func fetchTracks(albumID: String) async throws -> [Track] {
        if albumID == "a-rumours" { return Self.rumoursTracks }
        return (1...9).map { n in
            Track(id: "\(albumID)-t\(n)", albumID: albumID,
                  title: "Track \(n)", trackNumber: n, discNumber: 1,
                  durationMs: 180_000 + n * 17_000,
                  playPath: "/preview/\(albumID)/\(n)", thumbPath: nil)
        }
    }

    func streamRequest(for track: Track) throws -> MediaRequest {
        // Fail on purpose, like artwork. The old /dev/null URL built real
        // AVPlayerItems that all failed instantly, and AVQueuePlayer drops
        // failed items even while paused — the queue burned through to the
        // album's LAST track, so the now-playing screenshot showed "Gold
        // Dust Woman" instead of startAt: 2's "Never Going Back Again"
        // (the fixture order itself already matches fetchTracks' sort).
        // With no items enqueued the queue model keeps its start index.
        throw LibrarySourceError.noServer
    }

    func artworkRequest(path: String, width: Int, height: Int) throws -> MediaRequest {
        throw LibrarySourceError.noServer
    }

    static let genres: [Genre] = [
        "Ambient", "Blues", "Classical", "Electronic", "Folk", "Funk",
        "Hip-Hop", "Jazz", "Pop", "Punk", "Rock", "Soul",
    ].enumerated().map { Genre(id: "\($0.offset)", title: $0.element) }

    static let playlists: [Playlist] = [
        Playlist(id: "p1", title: "Road Trip", trackCount: 42,
                 durationMs: 9_780_000, thumbPath: nil),
        Playlist(id: "p2", title: "Quiet Morning", trackCount: 12,
                 durationMs: 2_950_000, thumbPath: nil),
        Playlist(id: "p3", title: "Gold Standard", trackCount: 25,
                 durationMs: 6_300_000, thumbPath: nil),
    ]

    // MARK: Fixture data (invented; wide letter spread to exercise the rail)

    static let artists: [Artist] = artistSeed.enumerated().map { index, seed in
        Artist(id: "ar\(index)", name: seed.0, albumCount: 0, thumbPath: nil)
    }

    static let albums: [Album] = artistSeed.enumerated().flatMap { index, seed -> [Album] in
        seed.1.enumerated().map { albumIndex, title in
            Album(id: title == "Rumours" ? "a-rumours" : "al\(index)-\(albumIndex)",
                  title: title,
                  artistID: "ar\(index)",
                  artistName: seed.0,
                  year: 1965 + (index * 3 + albumIndex * 7) % 55,
                  thumbPath: nil)
        }
    }

    static let rumoursTracks: [Track] = [
        ("Second Hand News", 163), ("Dreams", 257), ("Never Going Back Again", 134),
        ("Don't Stop", 191), ("Go Your Own Way", 218), ("Songbird", 200),
        ("The Chain", 270), ("You Make Loving Fun", 216), ("I Don't Want to Know", 195),
        ("Oh Daddy", 234), ("Gold Dust Woman", 295),
    ].enumerated().map { index, entry in
        Track(id: "rum-\(index + 1)", albumID: "a-rumours", title: entry.0,
              trackNumber: index + 1, discNumber: 1, durationMs: entry.1 * 1000,
              playPath: "/preview/rumours/\(index + 1)", thumbPath: nil)
    }

    /// (artist, albums) — letters A–Z plus a numeric artist for the "#" bucket.
    private static let artistSeed: [(String, [String])] = [
        ("The 1975", ["Being Funny in a Foreign Language"]),
        ("ABBA", ["Arrival", "The Visitors"]),
        ("Aretha Franklin", ["Lady Soul", "Young, Gifted and Black"]),
        ("The Beatles", ["Abbey Road", "Revolver", "Rubber Soul"]),
        ("Bob Dylan", ["Blood on the Tracks", "Highway 61 Revisited"]),
        ("Carole King", ["Tapestry"]),
        ("Creedence Clearwater Revival", ["Cosmo's Factory"]),
        ("David Bowie", ["Hunky Dory", "Low", "Station to Station"]),
        ("Dire Straits", ["Brothers in Arms"]),
        ("Elton John", ["Goodbye Yellow Brick Road", "Honky Château"]),
        ("Erykah Badu", ["Baduizm"]),
        ("Fleetwood Mac", ["Rumours", "Tusk"]),
        ("Funkadelic", ["Maggot Brain"]),
        ("Gil Scott-Heron", ["Pieces of a Man"]),
        ("Herbie Hancock", ["Head Hunters"]),
        ("Isaac Hayes", ["Hot Buttered Soul"]),
        ("Joni Mitchell", ["Blue", "Hejira", "Court and Spark"]),
        ("Kate Bush", ["Hounds of Love", "The Dreaming"]),
        ("Led Zeppelin", ["Physical Graffiti", "Led Zeppelin IV"]),
        ("Miles Davis", ["Kind of Blue", "In a Silent Way", "Bitches Brew"]),
        ("Nina Simone", ["I Put a Spell on You"]),
        ("Otis Redding", ["Otis Blue"]),
        ("Pink Floyd", ["Wish You Were Here", "Animals", "Meddle"]),
        ("Queen", ["A Night at the Opera"]),
        ("Radiohead", ["In Rainbows", "OK Computer", "Kid A"]),
        ("The Rolling Stones", ["Exile on Main St.", "Let It Bleed"]),
        ("Sade", ["Diamond Life", "Love Deluxe"]),
        ("Stevie Wonder", ["Songs in the Key of Life", "Innervisions", "Talking Book"]),
        ("Talk Talk", ["Spirit of Eden", "Laughing Stock"]),
        ("Tom Waits", ["Rain Dogs", "Swordfishtrombones"]),
        ("U2", ["The Joshua Tree"]),
        ("Van Morrison", ["Astral Weeks", "Moondance"]),
        ("The Who", ["Who's Next", "Quadrophenia"]),
        ("XTC", ["Skylarking"]),
        ("Yes", ["Close to the Edge"]),
        ("ZZ Top", ["Eliminator", "Tres Hombres"]),
        ("808 State", ["Ninety"]),
    ]
}
#endif
