import SongrKit
import SwiftUI

/// Phase switchboard: link → (library choice) → connect → the songr shell.
/// Every phase renders on the songr dark surface — no generic Apple chrome.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            SongrTheme.appBg.ignoresSafeArea()
            switch model.phase {
            case .launching:
                ProgressView().tint(SongrTheme.accent)
            case .needsLink, .linking:
                LinkView()
            case .connecting(let message):
                StatusScreen(message: message)
            case .choosingLibrary(let libraries):
                LibraryPickerView(libraries: libraries)
            case .failed(let message):
                FailureScreen(message: message)
            case .ready:
                SongrShell()
            }
        }
        .preferredColorScheme(.dark)
        .tint(SongrTheme.accent)
    }
}

/// Songr-styled progress interstitial (server discovery / first sync).
private struct StatusScreen: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            SongrWordmark(size: 15)
            ProgressView().tint(SongrTheme.accent)
            Text(message)
                .font(SongrTheme.font(14))
                .foregroundStyle(SongrTheme.soft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

private struct FailureScreen: View {
    @EnvironmentObject private var model: AppModel
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            SongrWordmark(size: 15)
            Text("Something Broke")
                .font(SongrTheme.font(20, .demiBold))
                .foregroundStyle(SongrTheme.textHigh)
            Text(message)
                .font(SongrTheme.font(14))
                .foregroundStyle(SongrTheme.error)
                .multilineTextAlignment(.center)
            SongrPanelButton(label: "Try Again") { model.retry() }
                .frame(maxWidth: 220)
        }
        .padding(32)
    }
}

// MARK: - The shell

/// Browse scopes, in the web chip row's build-v5 order (Artists · Albums ·
/// Genres · Recently played · Most played · Playlists · Recently added;
/// "Surprise me" has no mobile equivalent yet). Raw values double as
/// `-SongrPreviewScope` arguments.
enum BrowseScope: String, CaseIterable {
    case artists
    case albums
    case genres
    case recentlyPlayed = "recently-played"
    case mostPlayed = "most-played"
    case playlists
    case recentlyAdded = "recently-added"

    var label: String {
        switch self {
        case .artists: "Artists"
        case .albums: "Albums"
        case .genres: "Genres"
        case .recentlyPlayed: "Recently played"
        case .mostPlayed: "Most played"
        case .playlists: "Playlists"
        case .recentlyAdded: "Recently added"
        }
    }
}

/// The songr app frame, mirroring the web's `.u-app`: header bar (wordmark +
/// settings), a scope-chip row of its own (never crammed into the header, so
/// nothing clips in either orientation), the browse pane, and the player bar.
struct SongrShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var scope: BrowseScope
    /// Scopes whose pane has been built. Visited panes stay alive so every
    /// scope keeps its scroll position (the web pins per-scope scroll memory
    /// the same way); unvisited ones cost nothing — no server fetch fires
    /// until its chip is first tapped.
    @State private var visited: Set<BrowseScope>
    @State private var showNowPlaying: Bool
    @State private var showSettings = false

    init() {
        var initialScope = BrowseScope.artists
        var nowPlaying = false
        #if DEBUG
        // Scope selection works against the real library too (screenshot
        // verification drives the app by launch args, not taps).
        if let raw = UIPreviewHarness.value(after: "-SongrPreviewScope"),
           let previewScope = BrowseScope(rawValue: raw) {
            initialScope = previewScope
        }
        if UIPreviewHarness.isActive {
            nowPlaying = UIPreviewHarness.flag("-SongrPreviewNowPlaying")
        }
        #endif
        _scope = State(initialValue: initialScope)
        _visited = State(initialValue: [initialScope])
        _showNowPlaying = State(initialValue: nowPlaying)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            chipRow
            Rectangle().fill(SongrTheme.line).frame(height: 1)
            ZStack {
                ForEach(BrowseScope.allCases, id: \.self) { paneScope in
                    if visited.contains(paneScope) {
                        BrowsePane(scope: paneScope)
                            .opacity(scope == paneScope ? 1 : 0)
                            .allowsHitTesting(scope == paneScope)
                    }
                }
            }
            .background(SongrTheme.bg)
            if model.player.queue != nil {
                PlayerBar { showNowPlaying = true }
            }
        }
        .background(SongrTheme.header.ignoresSafeArea(edges: .top))
        .sheet(isPresented: $showNowPlaying) { NowPlayingView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    /// `.bar` — wordmark left, settings right; hairline underneath.
    private var headerBar: some View {
        HStack(spacing: 12) {
            SongrWordmark(size: 13)
            if model.isRefreshing {
                ProgressView()
                    .tint(SongrTheme.dim)
                    .scaleEffect(0.7)
            }
            Spacer()
            SongrBarButton(label: "Settings") { showSettings = true }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(SongrTheme.header)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SongrTheme.line).frame(height: 1)
        }
    }

    /// `.scopes` — the chip row lives on its own line with a fixed height,
    /// so chips can never be half cut off by a title or a rotation.
    private var chipRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BrowseScope.allCases, id: \.self) { chipScope in
                        SongrChip(label: chipScope.label, isOn: scope == chipScope) {
                            select(chipScope)
                        }
                        .id(chipScope)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            // The active chip is never left half-clipped at an edge.
            .onAppear { proxy.scrollTo(scope) }
            .onChange(of: scope) { _, newScope in
                withAnimation { proxy.scrollTo(newScope) }
            }
        }
        .background(SongrTheme.header)
    }

    private func select(_ newScope: BrowseScope) {
        let reselected = visited.contains(newScope)
        scope = newScope
        visited.insert(newScope)
        // A shelf revisit refreshes behind the kept scroll position — recency
        // shelves move whenever something plays. First visits load via the
        // pane's own .task.
        if reselected {
            Task { await model.loadShelf(newScope, force: true) }
        }
    }
}

/// One scope's navigation stack (list → artist → album), songr-chromed:
/// the system navigation bar stays hidden; pushed views draw the web's
/// `.ctx` back row instead.
private struct BrowsePane: View {
    let scope: BrowseScope
    @EnvironmentObject private var model: AppModel
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch scope {
                case .artists: ArtistsView()
                case .albums: AlbumsGridView()
                case .genres: GenresView()
                case .playlists: PlaylistsView()
                case .recentlyAdded, .recentlyPlayed, .mostPlayed:
                    AlbumShelfView(scope: scope)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Artist.self) { artist in
                ArtistAlbumsView(artist: artist)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(for: Genre.self) { genre in
                GenreAlbumsView(genre: genre)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlist: playlist)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onAppear {
            #if DEBUG
            // Screenshot harness: jump straight to one album's detail page.
            if UIPreviewHarness.isActive, scope == .artists, path.isEmpty,
               let title = UIPreviewHarness.value(after: "-SongrPreviewAlbum"),
               let album = AppModel.shared.snapshot?.albums
                   .first(where: { $0.title == title }) {
                path.append(album)
            }
            #endif
        }
        #if DEBUG
        // Screenshot harness for the server-fed scopes: once the shelf lands,
        // push the named genre/playlist detail (simctl cannot tap).
        .onChange(of: model.genres) { _, genres in
            if scope == .genres, path.isEmpty,
               let title = UIPreviewHarness.value(after: "-SongrPreviewGenre"),
               let genre = genres?.first(where: { $0.title == title }) {
                path.append(genre)
            }
        }
        .onChange(of: model.playlists) { _, playlists in
            if scope == .playlists, path.isEmpty,
               let title = UIPreviewHarness.value(after: "-SongrPreviewPlaylist"),
               let playlist = playlists?.first(where: { $0.title == title }) {
                path.append(playlist)
            }
        }
        #endif
    }
}

/// `.ctx` — the back/context row pushed pages carry: gold back control,
/// 20pt demi title, dim count fact on the right.
struct SongrContextRow: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var fact: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 11) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(SongrTheme.font(13))
                }
                .foregroundStyle(SongrTheme.accentBright)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            Text(title)
                .font(SongrTheme.font(20, .demiBold))
                .foregroundStyle(SongrTheme.textHigh)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let fact {
                Text(fact.uppercased())
                    .font(SongrTheme.font(11))
                    .tracking(1.2)
                    .foregroundStyle(SongrTheme.dim)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(SongrTheme.bg)
    }
}
