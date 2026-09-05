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

/// Native library destinations. Raw values also serve the preview harness.
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

    static let primary: [BrowseScope] = [.artists, .albums, .recentlyAdded, .recentlyPlayed]
    static let secondary: [BrowseScope] = [.genres, .mostPlayed, .playlists]

    var compactLabel: String {
        switch self {
        case .recentlyAdded: "Added"
        case .recentlyPlayed: "Played"
        default: label
        }
    }

    var symbol: String {
        switch self {
        case .artists: "person.2"
        case .albums: "square.stack"
        case .genres: "tag"
        case .recentlyAdded: "calendar.badge.plus"
        case .recentlyPlayed: "clock"
        case .mostPlayed: "chart.bar"
        case .playlists: "music.note.list"
        }
    }

    var isIndexed: Bool { self == .artists || self == .albums || self == .genres }

    var sortFields: [CatalogSortField] {
        switch self {
        case .artists: CatalogSortField.artistFields
        case .albums: CatalogSortField.albumFields
        default: [.name]
        }
    }
}

extension CatalogSortField {
    func label(for scope: BrowseScope) -> String {
        switch self {
        case .name: scope == .albums ? "Title" : "Name"
        case .artist: "Artist"
        case .year: "Year"
        case .dateAdded: "Date added"
        case .lastPlayed: "Last played"
        case .playCount: "Play count"
        case .albumCount: "Album count"
        }
    }
}

struct BrowseOrder: Hashable {
    var field: CatalogSortField = .name
    var direction: CatalogSortDirection = .ascending

    var isAlphabetical: Bool { field == .name || field == .artist }

    func directionLabel(_ direction: CatalogSortDirection) -> String {
        if isAlphabetical { return direction == .ascending ? "A–Z" : "Z–A" }
        if field == .playCount || field == .albumCount {
            return direction == .ascending ? "Fewest first" : "Most first"
        }
        return direction == .ascending ? "Oldest first" : "Newest first"
    }

    func apply<Element>(to sections: [CatalogSection<Element>]) -> [CatalogSection<Element>] {
        guard direction == .descending else { return sections }
        let letters = sections.filter { $0.title != "#" }.reversed()
        return (Array(letters) + sections.filter { $0.title == "#" }).map {
            CatalogSection(title: $0.title, items: Array($0.items.reversed()))
        }
    }
}

/// Candidate B: one compact header above the retained browse panes/player.
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
    @State private var paneAtRoot: [BrowseScope: Bool] = [:]
    @AppStorage("songr.phone.artists.order") private var artistDirection = CatalogSortDirection.ascending
    @AppStorage("songr.phone.albums.order") private var albumDirection = CatalogSortDirection.ascending
    @AppStorage("songr.phone.genres.order") private var genreDirection = CatalogSortDirection.ascending
    @AppStorage("songr.phone.artists.sort") private var artistSort = CatalogSortField.name
    @AppStorage("songr.phone.albums.sort") private var albumSort = CatalogSortField.name

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
            BrowseHeader(scope: scope, order: orderBinding(for: scope),
                         canSort: scope.isIndexed && paneAtRoot[scope, default: true],
                         isRefreshing: model.isRefreshing, select: select,
                         openSettings: { showSettings = true })
            ZStack {
                ForEach(BrowseScope.allCases, id: \.self) { paneScope in
                    if visited.contains(paneScope) {
                        BrowsePane(scope: paneScope, order: orderBinding(for: paneScope).wrappedValue) {
                            paneAtRoot[paneScope] = $0
                        }
                            .opacity(scope == paneScope ? 1 : 0)
                            .allowsHitTesting(scope == paneScope)
                            .accessibilityHidden(scope != paneScope)
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

    private func orderBinding(for scope: BrowseScope) -> Binding<BrowseOrder> {
        switch scope {
        case .artists:
            Binding(get: { BrowseOrder(field: artistSort, direction: artistDirection) },
                    set: { artistSort = $0.field; artistDirection = $0.direction })
        case .albums:
            Binding(get: { BrowseOrder(field: albumSort, direction: albumDirection) },
                    set: { albumSort = $0.field; albumDirection = $0.direction })
        case .genres:
            Binding(get: { BrowseOrder(direction: genreDirection) },
                    set: { genreDirection = $0.direction })
        default: .constant(BrowseOrder())
        }
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

/// Compact visual labels use full-height, separate touch targets. Every
/// primary destination stays directly accessible, including both recents.
private struct BrowseHeader: View {
    let scope: BrowseScope
    @Binding var order: BrowseOrder
    let canSort: Bool
    let isRefreshing: Bool
    let select: (BrowseScope) -> Void
    let openSettings: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    navigationRow(showBrand: false, iconsOnly: true)
                } else {
                    ViewThatFits(in: .horizontal) {
                        navigationRow(showBrand: true, iconsOnly: false)
                        navigationRow(showBrand: false, iconsOnly: false)
                        navigationRow(showBrand: false, iconsOnly: true)
                    }
                }
            }
            Spacer(minLength: 0)
            // Keep each native menu in one stable place as the primary labels adapt.
            libraryMenu
            if canSort { sortMenu }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(SongrTheme.header)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SongrTheme.line).frame(height: 1)
        }
        .accessibilityIdentifier("browse-header")
    }

    private func navigationRow(showBrand: Bool, iconsOnly: Bool) -> some View {
        HStack(spacing: 0) {
            if showBrand { wordmark }
            ForEach(BrowseScope.primary, id: \.self) { destination in
                scopeButton(destination, iconsOnly: iconsOnly)
            }
        }
    }

    private var wordmark: some View {
        SongrWordmark(size: 10)
            .frame(width: 34, height: 44)
            .overlay(alignment: .bottom) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.5)
                        .frame(height: 8)
                        .accessibilityLabel("Refreshing library")
                }
            }
    }

    private func scopeButton(_ destination: BrowseScope, iconsOnly: Bool) -> some View {
        Button { select(destination) } label: {
            Group {
                if iconsOnly {
                    headerIcon(destination.symbol, selected: scope == destination)
                } else {
                    headerLabel(destination.compactLabel, selected: scope == destination)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.label)
        .accessibilityAddTraits(scope == destination ? .isSelected : [])
        .accessibilityIdentifier("browse-\(destination.rawValue)")
    }

    private var libraryMenu: some View {
        let selected = BrowseScope.secondary.contains(scope)
        return Menu {
            Picker("Library", selection: Binding(get: { scope }, set: select)) {
                ForEach(BrowseScope.secondary, id: \.self) { destination in
                    Label(destination.label, systemImage: destination.symbol)
                        .tag(destination)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Settings", systemImage: "gearshape", action: openSettings)
        } label: {
            headerIcon("ellipsis", selected: selected)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .accessibilityLabel("More library views")
        .accessibilityValue(selected ? scope.label : "")
        .accessibilityIdentifier("browse-more")
    }

    private var sortMenu: some View {
        Menu {
            if scope.sortFields.count > 1 {
                Picker("Sort by", selection: Binding(get: { order.field }, set: { field in
                    order = BrowseOrder(field: field, direction: field.defaultDirection)
                })) {
                    ForEach(scope.sortFields, id: \.self) { field in
                        Text(field.label(for: scope)).tag(field)
                    }
                }
                .pickerStyle(.inline)
                Divider()
            }
            Picker("Order", selection: $order.direction) {
                ForEach(CatalogSortDirection.allCases, id: \.self) { direction in
                    Text(order.directionLabel(direction)).tag(direction)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(SongrTheme.soft)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Sort \(scope.label)")
        .accessibilityValue("\(order.field.label(for: scope)), \(order.directionLabel(order.direction))")
        .accessibilityIdentifier("browse-sort")
    }

    private func headerLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
        .font(.custom(SongrTheme.Weight.medium.face, size: 13, relativeTo: .subheadline))
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(selected ? SongrTheme.accentBright : SongrTheme.soft)
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .frame(minWidth: 44, minHeight: 44)
        .overlay(alignment: .bottom) {
            if selected {
                Rectangle().fill(SongrTheme.accent)
                    .frame(height: 1)
                    .padding(.horizontal, 7)
                    .padding(.bottom, 6)
            }
        }
        .contentShape(Rectangle())
    }

    private func headerIcon(_ symbol: String, selected: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(selected ? SongrTheme.accentBright : SongrTheme.soft)
            .frame(width: 44, height: 44)
            .overlay(alignment: .bottom) {
                if selected {
                    Rectangle().fill(SongrTheme.accent)
                        .frame(height: 1)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 6)
                }
            }
            .contentShape(Rectangle())
    }
}

/// One scope's navigation stack (list → artist → album), songr-chromed:
/// the system navigation bar stays hidden; pushed views draw the web's
/// `.ctx` back row instead.
private struct BrowsePane: View {
    let scope: BrowseScope
    let order: BrowseOrder
    let reportRoot: (Bool) -> Void
    @EnvironmentObject private var model: AppModel
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch scope {
                case .artists: ArtistsView(order: order)
                case .albums: AlbumsGridView(order: order)
                case .genres: GenresView(order: order)
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
        .onChange(of: path.count, initial: true) { _, count in
            reportRoot(count == 0)
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
