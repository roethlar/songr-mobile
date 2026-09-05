import Foundation

// MARK: - Models

/// A music-library artist. `albumCount` is definitive only after the catalog
/// store recomputes it from the album index; sources fill in what the server
/// reports (which some backends omit — Plex artist listings often do).
public struct Artist: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public var albumCount: Int
    public let thumbPath: String?

    public init(id: String, name: String, albumCount: Int, thumbPath: String?) {
        self.id = id
        self.name = name
        self.albumCount = albumCount
        self.thumbPath = thumbPath
    }
}

public struct Album: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let artistID: String
    public let artistName: String
    public let year: Int?
    /// Optional server facts; old catalog snapshots decode these as nil.
    public let addedAt: Date?
    public let lastPlayedAt: Date?
    public let playCount: Int?
    /// Backend-relative artwork path (e.g. Plex `/library/metadata/…/thumb/…`);
    /// resolve to a fetchable request via `LibrarySource.artworkRequest`.
    public let thumbPath: String?

    public init(id: String, title: String, artistID: String, artistName: String,
                year: Int?, thumbPath: String?, addedAt: Date? = nil,
                lastPlayedAt: Date? = nil, playCount: Int? = nil) {
        self.id = id
        self.title = title
        self.artistID = artistID
        self.artistName = artistName
        self.year = year
        self.addedAt = addedAt
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
        self.thumbPath = thumbPath
    }
}

public struct Track: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let albumID: String
    public let title: String
    public let trackNumber: Int
    public let discNumber: Int
    public let durationMs: Int?
    /// Backend-relative direct-play path (Plex: `Media[0].Part[0].key`).
    public let playPath: String
    public let thumbPath: String?
    /// Artist credited on the track (Plex `grandparentTitle`). Album fetches
    /// may omit it (the album already names the artist); playlist items carry
    /// it so cross-album queues can show who plays.
    public let artistName: String?

    public init(id: String, albumID: String, title: String, trackNumber: Int,
                discNumber: Int, durationMs: Int?, playPath: String, thumbPath: String?,
                artistName: String? = nil) {
        self.id = id
        self.albumID = albumID
        self.title = title
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.durationMs = durationMs
        self.playPath = playPath
        self.thumbPath = thumbPath
        self.artistName = artistName
    }
}

/// One genre tag of the music library (Plex `/library/sections/{key}/genre`
/// Directory row). `id` is the backend filter value (Plex numeric tag id as a
/// string) used to list the genre's albums.
public struct Genre: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// One audio playlist (Plex `/playlists?playlistType=audio` row).
public struct Playlist: Codable, Hashable, Sendable, Identifiable {
    /// Backend ratingKey.
    public let id: String
    public let title: String
    public let trackCount: Int
    public let durationMs: Int?
    /// Backend-relative artwork path (Plex `composite` mosaic).
    public let thumbPath: String?

    public init(id: String, title: String, trackCount: Int, durationMs: Int?,
                thumbPath: String?) {
        self.id = id
        self.title = title
        self.trackCount = trackCount
        self.durationMs = durationMs
        self.thumbPath = thumbPath
    }
}

/// An HTTP resource the player/UI may fetch directly (stream or artwork).
/// Auth rides in headers, never in the URL (matches the vela-trusted Plex
/// flow; AVURLAsset forwards headers via `AVURLAssetHTTPHeaderFieldsKey`).
public struct MediaRequest: Hashable, Sendable {
    public let url: URL
    public let headers: [String: String]

    public init(url: URL, headers: [String: String]) {
        self.url = url
        self.headers = headers
    }
}

public enum AuthState: Hashable, Sendable {
    case signedOut
    case signedIn
}

/// One selectable music library on the backend (a Plex `artist`-type section;
/// a Jellyfin music view later). Servers routinely hold several — music,
/// audiobooks, podcasts — so the choice is the user's, never a blind first-pick.
public struct MusicLibrary: Codable, Hashable, Sendable, Identifiable {
    /// Backend section key (Plex: the numeric section key as a string).
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

// MARK: - Protocol

/// Seam between the app and a concrete music backend. Plex today; the surface
/// is deliberately small and backend-neutral so a Jellyfin source can slot in
/// later (Jellyfin has the same shapes: auth, artists, albums, tracks, direct
/// stream + artwork URLs).
public protocol LibrarySource: Sendable {
    var authState: AuthState { get }

    /// All music libraries on the connected server, in server order.
    func fetchMusicLibraries() async throws -> [MusicLibrary]
    /// All artists in the music library (paged internally as needed).
    func fetchArtists() async throws -> [Artist]
    /// All albums in the music library (paged internally as needed).
    func fetchAlbums() async throws -> [Album]
    /// Tracks of one album, in disc/track order.
    func fetchTracks(albumID: String) async throws -> [Track]

    /// All genres tagged on the library's albums, in server order.
    func fetchGenres() async throws -> [Genre]
    /// Albums carrying one genre tag (paged internally as needed).
    func fetchAlbums(genreID: String) async throws -> [Album]
    /// All audio playlists on the server, in server order.
    func fetchPlaylists() async throws -> [Playlist]
    /// One playlist's tracks, in playlist order (never re-sorted).
    func fetchPlaylistTracks(playlistID: String) async throws -> [Track]
    /// Newest albums first (server `addedAt` descending), capped at `limit`.
    func fetchRecentlyAddedAlbums(limit: Int) async throws -> [Album]
    /// Albums played at least once, most recent play first, capped at `limit`.
    func fetchRecentlyPlayedAlbums(limit: Int) async throws -> [Album]
    /// Albums played at least once, most plays first, capped at `limit`.
    func fetchMostPlayedAlbums(limit: Int) async throws -> [Album]

    /// Direct-play stream request for a track.
    func streamRequest(for track: Track) throws -> MediaRequest
    /// Server-side-scaled artwork for a backend-relative artwork path.
    func artworkRequest(path: String, width: Int, height: Int) throws -> MediaRequest
}

public enum LibrarySourceError: Error, Equatable {
    case notAuthenticated
    case noServer
    case badResponse(status: Int)
    case malformedPayload(String)
    /// The server has several music libraries and none was configured.
    /// Carries the candidates so the caller can present a picker — a source
    /// must never silently pick one (owner ruling: wrong-library auto-pick).
    case ambiguousMusicLibraries([MusicLibrary])
}
