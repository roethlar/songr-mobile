import SongrKit
import SwiftUI

// The browse scopes beyond Artists/Albums, in songr's image (web library
// surface: Genres cards, Playlists rows, and the recency/play tile shelves).
// Each is fed straight from the server via AppModel's shelf loaders; the
// catalog snapshot never caches these.

// MARK: - Genres

/// Genres scope — the web's `.glist`/`.gcard` cards, A→Z under `.gl` letter
/// headings, with the same jump rail as artists/albums.
struct GenresView: View {
    @EnvironmentObject private var model: AppModel
    var order = BrowseOrder()

    private var sections: [CatalogSection<Genre>] {
        order.apply(to: CatalogIndexer.sections(of: model.genres ?? [], name: \.title))
    }

    var body: some View {
        Group {
            if let genres = model.genres, !genres.isEmpty {
                ScrollViewReader { proxy in
                    HStack(spacing: 0) {
                        AlphaJumpRail(activeTitles: Set(sections.map(\.title))) { title in
                            proxy.scrollTo(anchor(title), anchor: .top)
                        }
                        .zIndex(1)
                        Rectangle().fill(SongrTheme.line).frame(width: 1)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                BrowseScopeHeading(scope: .genres)
                                ForEach(sections, id: \.title) { section in
                                    SongrGroupHeading(title: section.title)
                                        .id(anchor(section.title))
                                        .padding(.bottom, 6)
                                    LazyVGrid(
                                        columns: [GridItem(.adaptive(minimum: 150, maximum: 260),
                                                           spacing: 9)],
                                        alignment: .leading, spacing: 9
                                    ) {
                                        ForEach(section.items) { genre in
                                            NavigationLink(value: genre) {
                                                GenreCard(genre: genre)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.bottom, 10)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                        }
                        .refreshable { await model.loadShelf(.genres, force: true) }
                    }
                }
                .id(order)
            } else {
                ScopeStatusView(scope: .genres, empty: "No genres in this library.")
            }
        }
        .background(SongrTheme.bg)
        .task { await model.loadShelf(.genres) }
    }

    private func anchor(_ title: String) -> String { "genres-\(title)" }
}

/// `.gcard` — inset card, hairline border, genre name.
private struct GenreCard: View {
    let genre: Genre

    var body: some View {
        HStack(spacing: 8) {
            Text(genre.title)
                .font(SongrTheme.font(14, .demiBold))
                .foregroundStyle(SongrTheme.textHigh)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SongrTheme.dim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 8).fill(SongrTheme.inset))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(SongrTheme.line, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

/// One genre's albums — fetched on entry, shown as the standard tile grid.
struct GenreAlbumsView: View {
    @EnvironmentObject private var model: AppModel
    let genre: Genre

    @State private var albums: [Album]?
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            SongrContextRow(
                title: genre.title,
                fact: albums.map { "\($0.count) \($0.count == 1 ? "album" : "albums")" }
            )
            if let albums {
                if albums.isEmpty {
                    StatusLine(text: "No albums carry this genre.")
                } else {
                    ScrollView {
                        AlbumGrid(albums: albums)
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                            .padding(.bottom, 24)
                    }
                }
            } else if loadFailed {
                StatusLine(text: "Couldn't load \(genre.title).", isError: true)
            } else {
                StatusLine(text: nil)
            }
        }
        .background(SongrTheme.bg)
        .task {
            guard albums == nil else { return }
            do {
                albums = try await model.albums(inGenre: genre)
            } catch {
                loadFailed = true
            }
        }
    }
}

// MARK: - Playlists

/// Playlists scope — audio playlists as songr rows: name, dotted leader,
/// track count + length.
struct PlaylistsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let playlists = model.playlists, !playlists.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        BrowseScopeHeading(scope: .playlists)
                        ForEach(playlists) { playlist in
                            NavigationLink(value: playlist) {
                                PlaylistRow(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .refreshable { await model.loadShelf(.playlists, force: true) }
            } else {
                ScopeStatusView(scope: .playlists,
                                empty: "No audio playlists on this server.")
            }
        }
        .background(SongrTheme.bg)
        .task { await model.loadShelf(.playlists) }
    }
}

/// A playlist row in the `.arow` idiom: name ····· "12 tracks · 43 min".
private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(playlist.title)
                .font(SongrTheme.font(16))
                .foregroundStyle(SongrTheme.listText)
                .lineLimit(1)
            DottedLeader()
            Text(fact)
                .font(SongrTheme.font(12))
                .foregroundStyle(SongrTheme.dim)
                .lineLimit(1)
                .fixedSize()  // the fact never wraps; the name truncates
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var fact: String {
        var parts = ["\(playlist.trackCount) \(playlist.trackCount == 1 ? "track" : "tracks")"]
        if let length = playlist.durationMs.map(Self.length(ms:)) {
            parts.append(length)
        }
        return parts.joined(separator: " · ")
    }

    static func length(ms: Int) -> String {
        let minutes = ms / 60_000
        return minutes >= 60 ? "\(minutes / 60) hr \(minutes % 60) min"
                             : "\(minutes) min"
    }
}

/// One playlist's tracks, in playlist order; tapping a row plays the
/// playlist from that track (the album-page rule, applied to playlists).
struct PlaylistDetailView: View {
    @EnvironmentObject private var model: AppModel
    let playlist: Playlist

    @State private var tracks: [Track] = []
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            SongrContextRow(
                title: playlist.title,
                fact: "\(playlist.trackCount) \(playlist.trackCount == 1 ? "track" : "tracks")"
            )
            if loadFailed {
                StatusLine(text: "Couldn't load this playlist.", isError: true)
            } else if tracks.isEmpty {
                StatusLine(text: nil)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SongrPanelButton(label: "Play") {
                            model.play(playlist: playlist, tracks: tracks, startAt: 0)
                        }
                        LazyVStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                PlaylistTrackRow(
                                    position: index + 1,
                                    track: track,
                                    isCurrent: model.player.currentTrack?.id == track.id
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.play(playlist: playlist, tracks: tracks,
                                               startAt: index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(SongrTheme.bg)
        .task {
            guard tracks.isEmpty else { return }
            do {
                tracks = try await model.tracks(in: playlist)
            } catch {
                loadFailed = true
            }
        }
    }
}

/// `.tr` for a cross-album list: position, title over artist, duration.
private struct PlaylistTrackRow: View {
    let position: Int
    let track: Track
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(SongrTheme.accent)
                    .frame(width: 26, alignment: .trailing)
            } else {
                Text("\(position)")
                    .font(SongrTheme.font(12).monospacedDigit())
                    .foregroundStyle(SongrTheme.dim)
                    .frame(width: 26, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(SongrTheme.font(15))
                    .foregroundStyle(isCurrent ? SongrTheme.accentBright
                                               : SongrTheme.listText)
                    .lineLimit(1)
                if let artist = track.artistName {
                    Text(artist)
                        .font(SongrTheme.font(11.5))
                        .foregroundStyle(SongrTheme.soft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let ms = track.durationMs {
                Text(Self.timestamp(ms: ms))
                    .font(SongrTheme.font(12).monospacedDigit())
                    .foregroundStyle(SongrTheme.dim)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isCurrent ? SongrTheme.hoverSubtle : .clear)
        )
    }

    static func timestamp(ms: Int) -> String {
        let totalSeconds = ms / 1000
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

// MARK: - Recency / play shelves

/// Recently added · Recently played · Most played — album tiles in server
/// order (recency IS the order, so no letter grouping and no rail), like the
/// web's tile shelves for these scopes.
struct AlbumShelfView: View {
    @EnvironmentObject private var model: AppModel
    let scope: BrowseScope

    private var albums: [Album]? {
        switch scope {
        case .recentlyAdded: model.recentlyAdded
        case .recentlyPlayed: model.recentlyPlayed
        case .mostPlayed: model.mostPlayed
        default: nil
        }
    }

    private var emptyText: String {
        switch scope {
        case .recentlyPlayed, .mostPlayed:
            "No plays on record yet — play something."
        default:
            "Nothing here yet."
        }
    }

    var body: some View {
        Group {
            if let albums, !albums.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        BrowseScopeHeading(scope: scope)
                        AlbumGrid(albums: albums)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .refreshable { await model.loadShelf(scope, force: true) }
            } else {
                ScopeStatusView(scope: scope, empty: emptyText)
            }
        }
        .background(SongrTheme.bg)
        .task { await model.loadShelf(scope) }
    }
}

// MARK: - Shared status surfaces

/// Secondary destinations identify themselves inside their scrollable content,
/// leaving the compact header's More label the same width in every scope.
private struct BrowseScopeHeading: View {
    let scope: BrowseScope

    var body: some View {
        Text(scope.label)
            .font(.custom(SongrTheme.Weight.demiBold.face, size: 14, relativeTo: .subheadline))
            .foregroundStyle(SongrTheme.soft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Loading / empty / error body for a whole scope pane, songr-quiet.
struct ScopeStatusView: View {
    @EnvironmentObject private var model: AppModel
    let scope: BrowseScope
    let empty: String

    var body: some View {
        VStack(spacing: 14) {
            BrowseScopeHeading(scope: scope)
                .padding(.horizontal, 18)
            Spacer()
            if let message = model.shelfErrors[scope] {
                Text(message)
                    .font(SongrTheme.font(14))
                    .foregroundStyle(SongrTheme.error)
                SongrPanelButton(label: "Try Again") {
                    Task { await model.loadShelf(scope, force: true) }
                }
                .frame(width: 160)
            } else if model.shelfLoaded(scope) {
                Text(empty)
                    .font(SongrTheme.font(14))
                    .foregroundStyle(SongrTheme.soft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                ProgressView().tint(SongrTheme.accent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Inline one-liner for pushed pages: spinner while `text` is nil, else the
/// message (error-tinted when asked).
private struct StatusLine: View {
    let text: String?
    var isError = false

    var body: some View {
        VStack {
            Spacer()
            if let text {
                Text(text)
                    .font(SongrTheme.font(13))
                    .foregroundStyle(isError ? SongrTheme.error : SongrTheme.soft)
            } else {
                ProgressView().tint(SongrTheme.accent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
