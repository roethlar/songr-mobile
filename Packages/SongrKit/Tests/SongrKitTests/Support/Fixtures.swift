import Foundation

/// Local JSON fixtures authored from the Plex API shapes vela exercises
/// (plex.tv v2 pins/resources, PMS sections/listings with container paging).
/// No fixture ever comes from the network.
enum Fixtures {
    static func data(_ json: String) -> Data { Data(json.utf8) }

    // MARK: plex.tv pins

    static let pinCreated = data("""
    {"id": 987654, "code": "ABCD", "product": "Songr", "trusted": false,
     "clientIdentifier": "songr-client-1", "expiresIn": 1800,
     "createdAt": "2026-08-30T12:00:00Z", "expiresAt": "2026-08-30T12:30:00Z",
     "authToken": null, "newRegistration": null}
    """)

    static let pinPending = data("""
    {"id": 987654, "code": "ABCD", "authToken": null}
    """)

    static let pinLinked = data("""
    {"id": 987654, "code": "ABCD", "authToken": "tok-secret-1"}
    """)

    // MARK: plex.tv resources

    static let resources = data("""
    [
      {"name": "halcyon", "product": "Plex Media Server",
       "productVersion": "1.41.0", "provides": "server",
       "clientIdentifier": "machine-1", "accessToken": "srv-token",
       "publicAddressMatches": true, "presence": true,
       "connections": [
         {"protocol": "https", "address": "192.168.1.10", "port": 32400,
          "uri": "https://192-168-1-10.abc123.plex.direct:32400",
          "local": true, "relay": false, "IPv6": false},
         {"protocol": "https", "address": "203.0.113.7", "port": 32400,
          "uri": "https://203-0-113-7.abc123.plex.direct:32400",
          "local": false, "relay": false, "IPv6": false},
         {"protocol": "https", "address": "172.16.5.5", "port": 8443,
          "uri": "https://relay-437.plex.direct:8443",
          "local": false, "relay": true, "IPv6": false}
       ]},
      {"name": "someone-elses-share", "provides": "client",
       "clientIdentifier": "machine-9", "connections": []}
    ]
    """)

    static func identity(machineIdentifier: String) -> Data {
        data("""
        {"MediaContainer": {"size": 0, "claimed": true,
         "machineIdentifier": "\(machineIdentifier)", "version": "1.41.0"}}
        """)
    }

    // MARK: PMS library

    static let sections = data("""
    {"MediaContainer": {"size": 3, "Directory": [
      {"key": "1", "type": "movie", "title": "Movies"},
      {"key": "5", "type": "artist", "title": "Music"},
      {"key": "7", "type": "photo", "title": "Photos"}
    ]}}
    """)

    /// The owner's real shape: music, podcasts, and audiobooks are separate
    /// `artist`-type sections — auto-pick must refuse and surface all three.
    static let sectionsMultiMusic = data("""
    {"MediaContainer": {"size": 4, "Directory": [
      {"key": "1", "type": "movie", "title": "Movies"},
      {"key": "5", "type": "artist", "title": "Music"},
      {"key": "8", "type": "artist", "title": "Podcasts"},
      {"key": "9", "type": "artist", "title": "Audiobooks"}
    ]}}
    """)

    /// Artists page 1 of 2 (totalSize 3, page size 2 in the test).
    static let artistsPage1 = data("""
    {"MediaContainer": {"size": 2, "totalSize": 3, "offset": 0, "Metadata": [
      {"ratingKey": "100", "type": "artist", "title": "ABBA",
       "thumb": "/library/metadata/100/thumb/1"},
      {"ratingKey": "101", "type": "artist", "title": "Éléphant"}
    ]}}
    """)

    static let artistsPage2 = data("""
    {"MediaContainer": {"size": 1, "totalSize": 3, "offset": 2, "Metadata": [
      {"ratingKey": "102", "type": "artist", "title": "The 1975",
       "thumb": "/library/metadata/102/thumb/1"}
    ]}}
    """)

    static let albumsPage = data("""
    {"MediaContainer": {"size": 3, "totalSize": 3, "offset": 0, "Metadata": [
      {"ratingKey": "200", "type": "album", "title": "Arrival",
       "parentRatingKey": "100", "parentTitle": "ABBA", "year": 1976,
       "thumb": "/library/metadata/200/thumb/1"},
      {"ratingKey": "201", "type": "album", "title": "Waterloo",
       "parentRatingKey": "100", "parentTitle": "ABBA", "year": 1974,
       "thumb": "/library/metadata/201/thumb/1"},
      {"ratingKey": "202", "type": "album", "title": "Notes",
       "parentRatingKey": "102", "parentTitle": "The 1975",
       "parentThumb": "/library/metadata/102/thumb/1"}
    ]}}
    """)

    /// Album children: tracks across two discs, deliberately out of order.
    static let albumTracks = data("""
    {"MediaContainer": {"size": 3, "totalSize": 3, "Metadata": [
      {"ratingKey": "302", "type": "track", "title": "Second on Disc Two",
       "index": 2, "parentIndex": 2, "duration": 180000,
       "parentThumb": "/library/metadata/200/thumb/1",
       "Media": [{"id": 9302, "Part": [
         {"id": 8302, "key": "/library/parts/8302/1700000000/file.flac",
          "duration": 180000, "container": "flac"}]}]},
      {"ratingKey": "300", "type": "track", "title": "Opener",
       "index": 1, "parentIndex": 1, "duration": 215000,
       "thumb": "/library/metadata/300/thumb/1",
       "Media": [{"id": 9300, "Part": [
         {"id": 8300, "key": "/library/parts/8300/1700000000/file.flac",
          "duration": 215000, "container": "flac"}]}]},
      {"ratingKey": "301", "type": "track", "title": "Closer of Disc One",
       "index": 2, "parentIndex": 1, "duration": 200000,
       "Media": [{"id": 9301, "Part": [
         {"id": 8301, "key": "/library/parts/8301/1700000000/file.flac",
          "duration": 200000, "container": "flac"}]}]}
    ]}}
    """)

    // MARK: Browse scopes (genres, playlists, recency/play shelves)

    /// `/library/sections/{key}/genre?type=9` — Directory rows; `key` is the
    /// numeric tag id, `fastKey` a ready-made filter path (unused, tolerated).
    static let genres = data("""
    {"MediaContainer": {"size": 3, "Directory": [
      {"fastKey": "/library/sections/5/all?genre=190", "key": "190",
       "title": "Rock", "type": "genre"},
      {"fastKey": "/library/sections/5/all?genre=204", "key": "204",
       "title": "Jazz", "type": "genre"},
      {"key": "310", "title": "Soul", "type": "genre"}
    ]}}
    """)

    /// `/playlists?playlistType=audio` — `composite` is the mosaic artwork;
    /// the smart playlist deliberately has none.
    static let playlists = data("""
    {"MediaContainer": {"size": 2, "totalSize": 2, "Metadata": [
      {"ratingKey": "900", "key": "/playlists/900/items", "type": "playlist",
       "title": "Road Trip", "playlistType": "audio", "smart": false,
       "composite": "/playlists/900/composite/1700000001",
       "duration": 5400000, "leafCount": 42},
      {"ratingKey": "901", "key": "/playlists/901/items", "type": "playlist",
       "title": "Quiet Morning", "playlistType": "audio", "smart": true,
       "duration": 1800000, "leafCount": 12}
    ]}}
    """)

    /// `/playlists/{id}/items` — playlist order is authoritative; the album
    /// track indexes here would REVERSE it if anything re-sorted by
    /// disc/track, which is exactly what the test guards against.
    static let playlistItems = data("""
    {"MediaContainer": {"size": 2, "totalSize": 2, "Metadata": [
      {"ratingKey": "300", "playlistItemID": 1, "type": "track",
       "title": "Dancing Queen",
       "parentRatingKey": "200", "parentTitle": "Arrival",
       "grandparentRatingKey": "100", "grandparentTitle": "ABBA",
       "index": 2, "parentIndex": 1, "duration": 215000,
       "thumb": "/library/metadata/300/thumb/1",
       "Media": [{"id": 9300, "Part": [
         {"id": 8300, "key": "/library/parts/8300/1700000000/file.flac",
          "duration": 215000, "container": "flac"}]}]},
      {"ratingKey": "310", "playlistItemID": 2, "type": "track",
       "title": "Milestones",
       "parentRatingKey": "210", "parentTitle": "Milestones",
       "grandparentRatingKey": "110", "grandparentTitle": "Miles Davis",
       "index": 1, "parentIndex": 1, "duration": 300000,
       "parentThumb": "/library/metadata/210/thumb/1",
       "Media": [{"id": 9310, "Part": [
         {"id": 8310, "key": "/library/parts/8310/1700000000/file.flac",
          "duration": 300000, "container": "flac"}]}]}
    ]}}
    """)

    /// Played-shelf page: server-side sort already applied, viewCount facts
    /// present the way PMS reports them.
    static let playedAlbums = data("""
    {"MediaContainer": {"size": 2, "totalSize": 2, "Metadata": [
      {"ratingKey": "201", "type": "album", "title": "Waterloo",
       "parentRatingKey": "100", "parentTitle": "ABBA", "year": 1974,
       "viewCount": 7, "lastViewedAt": 1756400000,
       "thumb": "/library/metadata/201/thumb/1"},
      {"ratingKey": "200", "type": "album", "title": "Arrival",
       "parentRatingKey": "100", "parentTitle": "ABBA", "year": 1976,
       "viewCount": 3, "lastViewedAt": 1756300000,
       "thumb": "/library/metadata/200/thumb/1"}
    ]}}
    """)
}
