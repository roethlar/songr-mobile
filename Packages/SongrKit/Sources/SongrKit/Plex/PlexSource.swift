import Foundation

/// LibrarySource backed by one chosen Plex Media Server connection.
/// Request shapes mirror vela (headers-only auth, JSON accept, container
/// paging as query parameters, photo transcode artwork, direct-play parts).
public actor PlexSource: LibrarySource {
    public let baseURL: URL
    public let identity: PlexClientIdentity
    private let token: String
    private let http: PlexHTTP
    private let pageSize: Int
    /// Section key chosen by the user (persisted by the app); nil means
    /// "resolve": auto-pick only when the server has exactly one music library.
    private let configuredSectionKey: String?
    private var musicSectionKey: String?

    public init(baseURL: URL,
                identity: PlexClientIdentity,
                token: String,
                sectionKey: String? = nil,
                session: URLSession = .shared,
                pageSize: Int = 200) {
        self.baseURL = baseURL
        self.identity = identity
        self.token = token
        self.configuredSectionKey = sectionKey
        self.http = PlexHTTP(session: session)
        self.pageSize = pageSize
    }

    public nonisolated var authState: AuthState {
        token.isEmpty ? .signedOut : .signedIn
    }

    // MARK: Payloads (tolerant: unknown fields ignored, optionals stay optional)

    private struct SectionsEnvelope: Decodable {
        struct Container: Decodable {
            struct Directory: Decodable {
                let key: String
                let type: String
                let title: String?
            }
            let Directory: [Directory]?
        }
        let MediaContainer: Container
    }

    private struct ListingEnvelope: Decodable {
        struct Container: Decodable {
            let size: Int?
            let totalSize: Int?
            let Metadata: [Item]?
        }
        struct Item: Decodable {
            struct Media: Decodable {
                struct Part: Decodable {
                    let key: String?
                }
                let Part: [Part]?
            }
            let ratingKey: String?
            let title: String?
            let parentRatingKey: String?
            let parentTitle: String?
            let grandparentTitle: String?
            let index: Int?
            let parentIndex: Int?
            let year: Int?
            let duration: Int?
            let thumb: String?
            let parentThumb: String?
            let composite: String?
            let childCount: Int?
            let leafCount: Int?
            let Media: [Media]?
        }
        let MediaContainer: Container
    }

    /// `/library/sections/{key}/genre` rows: Directory entries whose `key` is
    /// the numeric tag id used as the `?genre=` filter value.
    private struct TagsEnvelope: Decodable {
        struct Container: Decodable {
            struct Directory: Decodable {
                let key: String?
                let title: String?
            }
            let Directory: [Directory]?
        }
        let MediaContainer: Container
    }

    // MARK: Section lookup

    /// Every `type == "artist"` section, in server order. Plex models music,
    /// audiobook, and podcast libraries all as `artist` sections, so the list
    /// is exactly the set a user must choose between.
    public func fetchMusicLibraries() async throws -> [MusicLibrary] {
        let url = PlexHTTP.url(baseURL, path: "/library/sections")
        let envelope = try await http.get(SectionsEnvelope.self, url,
                                          headers: identity.headers(token: token))
        return (envelope.MediaContainer.Directory ?? [])
            .filter { $0.type == "artist" }
            .map { MusicLibrary(id: $0.key, title: $0.title ?? "Music") }
    }

    /// The music section browsing runs against: the configured key when the
    /// user chose one; otherwise auto-resolve only if the server has exactly
    /// one music library. More than one throws `.ambiguousMusicLibraries` —
    /// never a silent first-pick (owner's server: music + podcasts +
    /// audiobooks are separate artist sections).
    private func resolveMusicSectionKey() async throws -> String {
        if let musicSectionKey { return musicSectionKey }
        if let configuredSectionKey {
            musicSectionKey = configuredSectionKey
            return configuredSectionKey
        }
        let libraries = try await fetchMusicLibraries()
        switch libraries.count {
        case 0:
            throw LibrarySourceError.malformedPayload("no music (artist) section")
        case 1:
            musicSectionKey = libraries[0].id
            return libraries[0].id
        default:
            throw LibrarySourceError.ambiguousMusicLibraries(libraries)
        }
    }

    // MARK: Paged listing

    /// Plex metadata types within a music section.
    private enum MetadataType: String {
        case artist = "8"
        case album = "9"
    }

    private func fetchAllPages(path: String,
                               extraQuery: [(String, String)]) async throws -> [ListingEnvelope.Item] {
        var items: [ListingEnvelope.Item] = []
        var start = 0
        while true {
            let url = PlexHTTP.url(baseURL, path: path, query: extraQuery + [
                ("X-Plex-Container-Start", String(start)),
                ("X-Plex-Container-Size", String(pageSize)),
            ])
            let envelope = try await http.get(ListingEnvelope.self, url,
                                              headers: identity.headers(token: token))
            let page = envelope.MediaContainer.Metadata ?? []
            items.append(contentsOf: page)
            let total = envelope.MediaContainer.totalSize
                ?? envelope.MediaContainer.size
                ?? items.count
            start += page.count
            if page.isEmpty || start >= total { break }
        }
        return items
    }

    // MARK: LibrarySource

    public func fetchArtists() async throws -> [Artist] {
        let section = try await resolveMusicSectionKey()
        let items = try await fetchAllPages(
            path: "/library/sections/\(section)/all",
            extraQuery: [("type", MetadataType.artist.rawValue)]
        )
        return items.compactMap { item in
            guard let id = item.ratingKey, let name = item.title else { return nil }
            return Artist(id: id, name: name,
                          albumCount: item.childCount ?? 0,
                          thumbPath: item.thumb)
        }
    }

    public func fetchAlbums() async throws -> [Album] {
        let section = try await resolveMusicSectionKey()
        let items = try await fetchAllPages(
            path: "/library/sections/\(section)/all",
            extraQuery: [("type", MetadataType.album.rawValue)]
        )
        return Self.albums(from: items)
    }

    /// Shared album-row mapping for every album listing (full index, genre
    /// filter, recency/play shelves).
    private static func albums(from items: [ListingEnvelope.Item]) -> [Album] {
        items.compactMap { item in
            guard let id = item.ratingKey, let title = item.title else { return nil }
            return Album(id: id, title: title,
                         artistID: item.parentRatingKey ?? "",
                         artistName: item.parentTitle ?? "Unknown Artist",
                         year: item.year,
                         thumbPath: item.thumb ?? item.parentThumb)
        }
    }

    public func fetchTracks(albumID: String) async throws -> [Track] {
        let items = try await fetchAllPages(
            path: "/library/metadata/\(albumID)/children",
            extraQuery: []
        )
        let tracks: [Track] = items.compactMap { item in
            guard let id = item.ratingKey,
                  let title = item.title,
                  let partKey = item.Media?.first?.Part?.first?.key
            else { return nil }
            return Track(id: id, albumID: albumID, title: title,
                         trackNumber: item.index ?? 0,
                         discNumber: item.parentIndex ?? 1,
                         durationMs: item.duration,
                         playPath: partKey,
                         thumbPath: item.thumb ?? item.parentThumb)
        }
        return tracks.sorted {
            ($0.discNumber, $0.trackNumber) < ($1.discNumber, $1.trackNumber)
        }
    }

    // MARK: Browse scopes (genres, playlists, recency/play shelves)

    /// `type=9` on the tag listing keys the genres to albums, so each row's
    /// id filters `all?type=9&genre={id}` directly.
    public func fetchGenres() async throws -> [Genre] {
        let section = try await resolveMusicSectionKey()
        let url = PlexHTTP.url(
            baseURL, path: "/library/sections/\(section)/genre",
            query: [("type", MetadataType.album.rawValue)]
        )
        let envelope = try await http.get(TagsEnvelope.self, url,
                                          headers: identity.headers(token: token))
        return (envelope.MediaContainer.Directory ?? []).compactMap { row in
            guard let key = row.key, let title = row.title else { return nil }
            return Genre(id: key, title: title)
        }
    }

    public func fetchAlbums(genreID: String) async throws -> [Album] {
        let section = try await resolveMusicSectionKey()
        let items = try await fetchAllPages(
            path: "/library/sections/\(section)/all",
            extraQuery: [("type", MetadataType.album.rawValue),
                         ("genre", genreID)]
        )
        return Self.albums(from: items)
    }

    public func fetchPlaylists() async throws -> [Playlist] {
        let items = try await fetchAllPages(
            path: "/playlists",
            extraQuery: [("playlistType", "audio")]
        )
        return items.compactMap { item in
            guard let id = item.ratingKey, let title = item.title else { return nil }
            return Playlist(id: id, title: title,
                            trackCount: item.leafCount ?? 0,
                            durationMs: item.duration,
                            thumbPath: item.composite ?? item.thumb)
        }
    }

    /// Playlist order is the playlist's own — never re-sorted here.
    public func fetchPlaylistTracks(playlistID: String) async throws -> [Track] {
        let items = try await fetchAllPages(
            path: "/playlists/\(playlistID)/items",
            extraQuery: []
        )
        return items.compactMap { item in
            guard let id = item.ratingKey,
                  let title = item.title,
                  let partKey = item.Media?.first?.Part?.first?.key
            else { return nil }
            return Track(id: id, albumID: item.parentRatingKey ?? "",
                         title: title,
                         trackNumber: item.index ?? 0,
                         discNumber: item.parentIndex ?? 1,
                         durationMs: item.duration,
                         playPath: partKey,
                         thumbPath: item.thumb ?? item.parentThumb,
                         artistName: item.grandparentTitle)
        }
    }

    public func fetchRecentlyAddedAlbums(limit: Int) async throws -> [Album] {
        try await fetchAlbumShelf(sort: "addedAt:desc", playedOnly: false,
                                  limit: limit)
    }

    public func fetchRecentlyPlayedAlbums(limit: Int) async throws -> [Album] {
        try await fetchAlbumShelf(sort: "lastViewedAt:desc", playedOnly: true,
                                  limit: limit)
    }

    public func fetchMostPlayedAlbums(limit: Int) async throws -> [Album] {
        try await fetchAlbumShelf(sort: "viewCount:desc", playedOnly: true,
                                  limit: limit)
    }

    /// One capped request against the album index with a server-side sort.
    /// `playedOnly` adds Plex's `viewCount>>=0` filter (`>>` is Plex's
    /// greater-than operator), keeping never-played albums out of the played
    /// shelves.
    private func fetchAlbumShelf(sort: String, playedOnly: Bool,
                                 limit: Int) async throws -> [Album] {
        let section = try await resolveMusicSectionKey()
        var query: [(String, String)] = [
            ("type", MetadataType.album.rawValue),
            ("sort", sort),
        ]
        if playedOnly { query.append(("viewCount>>", "0")) }
        query.append(("X-Plex-Container-Start", "0"))
        query.append(("X-Plex-Container-Size", String(limit)))
        let url = PlexHTTP.url(baseURL,
                               path: "/library/sections/\(section)/all",
                               query: query)
        let envelope = try await http.get(ListingEnvelope.self, url,
                                          headers: identity.headers(token: token))
        return Self.albums(from: envelope.MediaContainer.Metadata ?? [])
    }

    // MARK: Media requests (sync, derived from immutable config)

    /// Headers for media fetches; no JSON accept, token still header-borne.
    private nonisolated var mediaHeaders: [String: String] {
        var headers = identity.headers(token: token)
        headers.removeValue(forKey: "Accept")
        return headers
    }

    public nonisolated func streamRequest(for track: Track) throws -> MediaRequest {
        guard !token.isEmpty else { throw LibrarySourceError.notAuthenticated }
        return MediaRequest(url: PlexHTTP.url(baseURL, path: track.playPath),
                            headers: mediaHeaders)
    }

    public nonisolated func artworkRequest(path: String, width: Int, height: Int) throws -> MediaRequest {
        guard !token.isEmpty else { throw LibrarySourceError.notAuthenticated }
        let url = PlexHTTP.url(baseURL, path: "/photo/:/transcode", query: [
            ("width", String(width)),
            ("height", String(height)),
            ("minSize", "1"),
            ("upscale", "1"),
            ("url", path),
        ])
        return MediaRequest(url: url, headers: mediaHeaders)
    }
}
