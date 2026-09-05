import Combine
import Foundation
import SongrKit
import UIKit
import os

/// App-level state shared by the phone UI and the CarPlay scene: Plex auth,
/// the chosen server, the cached catalog, and the player.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Phase: Equatable {
        case launching
        /// No Plex token yet — show the sign-in screen.
        case needsLink
        /// PINs issued; in-app sign-in URL + external-browser code, polling both.
        case linking(url: URL, code: String)
        /// Token present; discovering a reachable server / first sync.
        case connecting(String)
        /// The server has several music libraries — the user must choose
        /// (owner ruling: never silently pick when ambiguous).
        case choosingLibrary([MusicLibrary])
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var snapshot: CatalogSnapshot?
    @Published private(set) var isRefreshing = false

    // Browse scope shelves: fetched straight from the server per visit, never
    // folded into the catalog snapshot (recency/play facts go stale offline).
    @Published private(set) var genres: [Genre]?
    @Published private(set) var playlists: [Playlist]?
    @Published private(set) var recentlyAdded: [Album]?
    @Published private(set) var recentlyPlayed: [Album]?
    @Published private(set) var mostPlayed: [Album]?
    @Published private(set) var shelfErrors: [BrowseScope: String] = [:]
    private var shelvesLoading: Set<BrowseScope> = []
    private var genreAlbums: [String: [Album]] = [:]
    /// Shelf cap — one capped request per shelf, plenty for a browse row.
    private let shelfLimit = 60

    let player = PlayerEngine()

    private let credentials: PlexCredentialStoring
    private var catalogStore: CatalogStore
    private(set) var source: LibrarySource?
    private var linkTask: Task<Void, Never>?
    private let artworkCache = NSCache<NSString, UIImage>()
    private var cancellables: Set<AnyCancellable> = []
    private let log = Logger(subsystem: "com.draegloth.Songr", category: "connect")

    /// Keychain-backed credentials (kSecClassGenericPassword, no iCloud
    /// sync): reinstalls and rebuilds keep the Plex link, unlike the original
    /// UserDefaults store that a reinstall wiped — which once cost the owner
    /// his sign-in. First construction after the switch imports the legacy
    /// UserDefaults values and deletes the plaintext copies.
    nonisolated static func makePersistentCredentialStore() -> PlexCredentialStoring {
        let store = KeychainCredentialStore()
        store.migrateFromUserDefaults()
        return store
    }

    init(credentials: PlexCredentialStoring = AppModel.makePersistentCredentialStore()) {
        self.credentials = credentials
        let caches = FileManager.default.urls(for: .cachesDirectory,
                                              in: .userDomainMask).first!
        self.catalogStore = CatalogStore(directory: caches.appendingPathComponent("Songr"))
        artworkCache.countLimit = 600
        // Views observe AppModel; surface the nested player's changes too.
        player.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private var identity: PlexClientIdentity {
        PlexClientIdentity(
            clientIdentifier: PlexClientIdentity.ensureClientIdentifier(in: credentials)
        )
    }

    // MARK: Lifecycle

    private var started = false

    /// Idempotent: whichever scene connects first kicks things off.
    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        if UIPreviewHarness.isActive {
            UIPreviewHarness.apply(to: self)
            return
        }
        #endif
        guard credentials.authToken != nil else {
            phase = .needsLink
            return
        }
        Task { await connect() }
    }

    #if DEBUG
    /// UI-preview seams (screenshot verification without a live Plex link).
    func previewInstall(source: LibrarySource, snapshot: CatalogSnapshot) {
        self.source = source
        self.snapshot = snapshot
        phase = .ready
    }

    func previewShowLibraryPicker(_ libraries: [MusicLibrary]) {
        phase = .choosingLibrary(libraries)
    }
    #endif

    // MARK: Plex PIN link

    func beginLink() {
        linkTask?.cancel()
        linkTask = Task { [weak self] in
            await self?.runLinkFlow()
        }
    }

    func cancelLink() {
        linkTask?.cancel()
        linkTask = nil
        phase = .needsLink
    }

    private func runLinkFlow() async {
        let pinClient = PlexPinClient(identity: identity)
        do {
            // Both pin types: strong feeds the in-app sign-in page, weak gives
            // a short code for plex.tv/link in any external browser.
            async let strongReq = pinClient.requestPin(strong: true)
            async let weakReq = pinClient.requestPin(strong: false)
            let (hosted, coded) = try await (strongReq, weakReq)
            phase = .linking(url: pinClient.authAppURL(for: hosted),
                             code: coded.code)
            // plex.tv pins live ~30 minutes; poll every 2s until then.
            for _ in 0..<900 {
                try await Task.sleep(for: .seconds(2))
                for id in [hosted.id, coded.id] {
                    if let token = try? await pinClient.pollToken(pinID: id) {
                        credentials.authToken = token
                        await connect()
                        return
                    }
                }
            }
            phase = .failed("The Plex sign-in expired. Try again.")
        } catch is CancellationError {
            // cancelLink already reset the phase.
        } catch {
            phase = .failed("Could not reach plex.tv: \(error.localizedDescription)")
        }
    }

    /// Wipes the token (e.g. server says 401) and returns to the link screen.
    func unlink() {
        credentials.authToken = nil
        credentials.serverURL = nil
        credentials.serverMachineIdentifier = nil
        credentials.musicSectionKey = nil
        source = nil
        snapshot = nil
        clearShelves()
        started = true
        phase = .needsLink
    }

    // MARK: Server choice + catalog

    private func connect() async {
        guard let token = credentials.authToken else {
            phase = .needsLink
            return
        }
        phase = .connecting("Finding your Plex server…")
        let discovery = PlexDiscovery(identity: identity, token: token)

        var chosen: PlexServerCandidate?
        // Try the server that worked last time before full discovery.
        if let savedURL = credentials.serverURL,
           let machine = credentials.serverMachineIdentifier {
            let saved = PlexServerCandidate(name: "saved",
                                            machineIdentifier: machine,
                                            uri: savedURL, local: false, relay: false)
            if await discovery.probe(saved) {
                chosen = saved
            }
            log.info("saved-server probe \(machine, privacy: .public) @ \(savedURL, privacy: .public): \(chosen != nil ? "hit" : "miss", privacy: .public)")
        }
        if chosen == nil {
            do {
                let candidates = try await discovery.fetchServerCandidates()
                for c in candidates {
                    log.info("candidate \(c.name, privacy: .public) machine=\(c.machineIdentifier, privacy: .public) uri=\(c.uri, privacy: .public) local=\(c.local) relay=\(c.relay)")
                }
                chosen = await discovery.chooseServer(from: candidates)
            } catch {
                phase = .failed("Server discovery failed: \(error.localizedDescription)")
                return
            }
        }
        guard let server = chosen else {
            phase = .failed("No reachable Plex server. Check that the server is on and signed in to your account.")
            return
        }
        credentials.serverURL = server.uri
        credentials.serverMachineIdentifier = server.machineIdentifier
        log.info("chosen server \(server.name, privacy: .public) machine=\(server.machineIdentifier, privacy: .public) uri=\(server.uri, privacy: .public)")
        log.info("stored musicSectionKey=\(self.credentials.musicSectionKey ?? "nil", privacy: .public)")

        // Enumerate libraries whenever no key is stored, OR to validate a
        // stored key. A stale key (e.g. from the retired blind first-pick,
        // or a rebuilt server) must never silently win.
        phase = .connecting("Reading your libraries…")
        let probe = PlexSource(baseURL: server.uri, identity: identity,
                               token: token)
        do {
            let libraries = try await probe.fetchMusicLibraries()
            log.info("music libraries: \(libraries.map { "\($0.id)=\($0.title)" }.joined(separator: ", "), privacy: .public)")
            if let stored = credentials.musicSectionKey,
               !libraries.contains(where: { $0.id == stored }) {
                log.info("stored key \(stored, privacy: .public) not on server — clearing")
                credentials.musicSectionKey = nil
            }
            if credentials.musicSectionKey == nil {
                switch libraries.count {
                case 0:
                    phase = .failed("This Plex server has no music library.")
                    return
                case 1:
                    log.info("single library — silent pick \(libraries[0].id, privacy: .public)")
                    credentials.musicSectionKey = libraries[0].id
                default:
                    // More than one → always the picker. Never a blind pick.
                    self.source = probe
                    phase = .choosingLibrary(libraries)
                    return
                }
            }
        } catch {
            phase = .failed("Could not read the server's libraries: \(error.localizedDescription)")
            return
        }

        self.source = PlexSource(baseURL: server.uri, identity: identity,
                                 token: token,
                                 sectionKey: credentials.musicSectionKey)
        rekeyCatalogStore()
        await loadCatalog()
    }

    /// The cache file is keyed by (server, section). The original un-keyed
    /// catalog.json let a snapshot synced from one library (audiobooks) be
    /// shown after switching to another (music) until a refresh overwrote
    /// it — the "keeps switching libraries" bug. The legacy file is deleted
    /// so it can never resurface.
    private func rekeyCatalogStore() {
        let caches = FileManager.default.urls(for: .cachesDirectory,
                                              in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("Songr")
        let machine = credentials.serverMachineIdentifier ?? "none"
        let section = credentials.musicSectionKey ?? "none"
        catalogStore = CatalogStore(directory: dir,
                                    fileName: "catalog-\(machine)-\(section).json")
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("catalog.json"))
    }

    private func loadCatalog() async {
        if let cached = await catalogStore.loadCached() {
            log.info("showing cached catalog: \(cached.artists.count) artists, \(cached.albums.count) albums")
            snapshot = cached
            phase = .ready
            Task { await refreshCatalog() }  // freshen behind the cached UI
        } else {
            phase = .connecting("Syncing your library…")
            await refreshCatalog()
            if case .choosingLibrary = phase { return }
            phase = snapshot == nil
                ? .failed("Could not load the music library.")
                : .ready
        }
    }

    // MARK: Music library choice

    var currentSectionKey: String? { credentials.musicSectionKey }

    /// The user picked a library (first run, or a change from settings).
    func selectLibrary(_ library: MusicLibrary) {
        guard let token = credentials.authToken,
              let serverURL = credentials.serverURL else { return }
        let changed = credentials.musicSectionKey != library.id
        log.info("user picked library \(library.id, privacy: .public)=\(library.title, privacy: .public) changed=\(changed)")
        credentials.musicSectionKey = library.id
        source = PlexSource(baseURL: serverURL, identity: identity,
                            token: token, sectionKey: library.id)
        rekeyCatalogStore()
        clearShelves()  // every shelf came from the previous source instance
        Task {
            if changed {
                await catalogStore.clear()
                snapshot = nil
            }
            phase = .connecting("Syncing \(library.title)…")
            await refreshCatalog()
            if case .choosingLibrary = phase { return }
            phase = snapshot == nil
                ? .failed("Could not load \(library.title).")
                : .ready
        }
    }

    /// Back out of the picker (only offered while a library is active).
    func cancelLibraryChoice() {
        guard snapshot != nil else { return }
        phase = .ready
    }

    func retry() {
        guard credentials.authToken != nil else {
            phase = .needsLink
            return
        }
        Task { await connect() }
    }

    func refreshCatalog() async {
        guard let source, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await catalogStore.refresh(from: source)
            log.info("refresh done: \(self.snapshot?.artists.count ?? -1) artists, \(self.snapshot?.albums.count ?? -1) albums")
        } catch LibrarySourceError.badResponse(let status) where status == 401 {
            unlink()
        } catch LibrarySourceError.ambiguousMusicLibraries(let libraries) {
            credentials.musicSectionKey = nil
            phase = .choosingLibrary(libraries)
        } catch {
            // Keep whatever snapshot we had; surface only if we have nothing.
            if snapshot == nil {
                phase = .failed("Library sync failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Browse helpers

    func albums(forArtist artistID: String) -> [Album] {
        snapshot?.albums(forArtist: artistID) ?? []
    }

    func tracks(for album: Album) async throws -> [Track] {
        guard let source else { throw LibrarySourceError.noServer }
        return try await source.fetchTracks(albumID: album.id)
    }

    // MARK: Browse scope shelves

    func shelfLoaded(_ scope: BrowseScope) -> Bool {
        switch scope {
        case .artists, .albums: snapshot != nil
        case .genres: genres != nil
        case .playlists: playlists != nil
        case .recentlyAdded: recentlyAdded != nil
        case .recentlyPlayed: recentlyPlayed != nil
        case .mostPlayed: mostPlayed != nil
        }
    }

    /// Fetches one scope's shelf. `force` refetches even when loaded (chip
    /// re-select, pull-to-refresh); the stale shelf stays on screen until the
    /// fresh one lands. 401 unlinks, like the catalog refresh.
    func loadShelf(_ scope: BrowseScope, force: Bool = false) async {
        guard let source,
              !shelvesLoading.contains(scope),
              force || !shelfLoaded(scope) else { return }
        shelvesLoading.insert(scope)
        defer { shelvesLoading.remove(scope) }
        do {
            switch scope {
            case .artists, .albums:
                return  // catalog snapshot scopes; refreshCatalog owns these
            case .genres:
                genres = try await source.fetchGenres()
            case .playlists:
                playlists = try await source.fetchPlaylists()
            case .recentlyAdded:
                recentlyAdded = try await source.fetchRecentlyAddedAlbums(limit: shelfLimit)
            case .recentlyPlayed:
                recentlyPlayed = try await source.fetchRecentlyPlayedAlbums(limit: shelfLimit)
            case .mostPlayed:
                mostPlayed = try await source.fetchMostPlayedAlbums(limit: shelfLimit)
            }
            shelfErrors[scope] = nil
        } catch LibrarySourceError.badResponse(let status) where status == 401 {
            unlink()
        } catch {
            log.info("shelf \(scope.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            shelfErrors[scope] = "Couldn't load \(scope.label.lowercased())."
        }
    }

    /// Server or library changed — every shelf belongs to the old source.
    private func clearShelves() {
        genres = nil
        playlists = nil
        recentlyAdded = nil
        recentlyPlayed = nil
        mostPlayed = nil
        shelfErrors = [:]
        genreAlbums = [:]
    }

    /// One genre's albums, fetched once per session and kept in memory.
    func albums(inGenre genre: Genre) async throws -> [Album] {
        if let cached = genreAlbums[genre.id] { return cached }
        guard let source else { throw LibrarySourceError.noServer }
        let albums = try await source.fetchAlbums(genreID: genre.id)
        genreAlbums[genre.id] = albums
        return albums
    }

    func tracks(in playlist: Playlist) async throws -> [Track] {
        guard let source else { throw LibrarySourceError.noServer }
        return try await source.fetchPlaylistTracks(playlistID: playlist.id)
    }

    /// Plays a playlist from a track. The queue's display "album" is the
    /// playlist itself (title + composite art); each track carries its own
    /// artist credit for the now-playing surfaces.
    func play(playlist: Playlist, tracks: [Track], startAt index: Int) {
        guard let source else { return }
        let sleeve = Album(id: "playlist:\(playlist.id)", title: playlist.title,
                           artistID: "", artistName: "Playlist", year: nil,
                           thumbPath: playlist.thumbPath)
        player.play(album: sleeve, tracks: tracks, startIndex: index, source: source)
    }

    // MARK: Playback

    func play(album: Album, tracks: [Track], startAt index: Int) {
        guard let source else { return }
        player.play(album: album, tracks: tracks, startIndex: index, source: source)
    }

    /// Fetches the album's tracks and plays from the given index (CarPlay path).
    func play(album: Album, startAt index: Int) async {
        guard let tracks = try? await tracks(for: album), !tracks.isEmpty else { return }
        play(album: album, tracks: tracks, startAt: index)
    }

    // MARK: Artwork

    /// Server-scaled artwork, memory-cached. `pixels` is the longest edge.
    func artwork(path: String?, pixels: Int) async -> UIImage? {
        guard let path, let source else { return nil }
        let key = "\(path)#\(pixels)" as NSString
        if let hit = artworkCache.object(forKey: key) { return hit }
        guard let request = try? source.artworkRequest(path: path,
                                                       width: pixels, height: pixels)
        else { return nil }
        var urlRequest = URLRequest(url: request.url)
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        guard let (data, response) = try? await URLSession.shared.data(for: urlRequest),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data)
        else { return nil }
        artworkCache.setObject(image, forKey: key)
        return image
    }
}
