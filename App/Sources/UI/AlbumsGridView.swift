import SongrKit
import SwiftUI

/// Whole-library artwork grid with a persistent index. Alphabetical orders
/// group by title or artist; metadata orders keep their sorted sequence intact.
struct AlbumsGridView: View {
    @EnvironmentObject private var model: AppModel
    var order = BrowseOrder()

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(1, geometry.size.width - AlphaJumpRail.railWidth - 1 - 36)
            let columns = max(1, Int((contentWidth + 16) / (116 + 16)))
            let tileWidth = min(190, max(1, (contentWidth - CGFloat(columns - 1) * 16) / CGFloat(columns)))
            let albums = CatalogOrdering.albums(model.snapshot?.albums ?? [],
                                                by: order.field, direction: order.direction)
            let sections = sections(for: albums)
            let rows = browseRows(sections: sections, columns: columns)
            let targets = jumpTargets(albums: albums, sections: sections, rows: rows)
            AlbumBrowseContent(rows: rows, targets: targets, tileWidth: tileWidth,
                indexLabel: order.field == .artist ? "Jump by artist name" : "Jump by album title")
                .id(order)
        }
    }

    private func sections(for albums: [Album]) -> [CatalogSection<Album>] {
        if order.isAlphabetical {
            return CatalogOrdering.alphabeticalSections(albums,
                name: { order.field == .artist ? $0.artistName : $0.title }, direction: order.direction)
        }
        return [CatalogSection(title: order.field.label(for: .albums), items: albums)]
    }

    private func anchor(_ title: String) -> String { "albums-\(title)" }

    private func browseRows(sections: [CatalogSection<Album>], columns: Int) -> [AlbumBrowseRow] {
        sections.flatMap { section in
            [AlbumBrowseRow(id: anchor(section.title), heading: section.title, albums: [])]
            + stride(from: 0, to: section.items.count, by: columns).map { offset in
                AlbumBrowseRow(id: "\(anchor(section.title))-row-\(offset / columns)", heading: nil,
                               albums: Array(section.items[offset..<min(offset + columns, section.items.count)]))
            }
        }
    }

    private func jumpTargets(albums: [Album], sections: [CatalogSection<Album>],
                             rows: [AlbumBrowseRow]) -> [String: String] {
        if order.isAlphabetical {
            return Dictionary(uniqueKeysWithValues: sections.map { ($0.title, anchor($0.title)) })
        }
        let first = CatalogOrdering.firstLetterIndices(albums, name: \.title)
        var rowForAlbum: [String: String] = [:]
        for row in rows {
            for album in row.albums { rowForAlbum[album.id] = row.id }
        }
        return first.compactMapValues { rowForAlbum[albums[$0].id] }
    }
}

/// Scroll position belongs to this rendered catalog, so dragging does not
/// re-sort the full library and changing order starts with a fresh position.
private struct AlbumBrowseContent: View {
    @EnvironmentObject private var model: AppModel
    let rows: [AlbumBrowseRow]
    let targets: [String: String]
    let tileWidth: CGFloat
    let indexLabel: String
    @State private var scrollTarget: String?

    var body: some View {
        HStack(spacing: 0) {
            AlphaJumpRail(activeTitles: Set(targets.keys), indexLabel: indexLabel) { title in
                if let target = targets[title] { scrollTarget = target }
            }
            .zIndex(1)
            Rectangle().fill(SongrTheme.line).frame(width: 1)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        if let heading = row.heading {
                            SongrGroupHeading(title: heading)
                                .padding(.bottom, 4)
                                .id(row.id)
                        } else {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(row.albums) { album in
                                    NavigationLink(value: album) {
                                        AlbumTile(album: album, reservesTitleSpace: true)
                                            .frame(width: tileWidth)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 20)
                            .id(row.id)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollPosition(id: $scrollTarget, anchor: .top)
            .refreshable { await model.refreshCatalog() }
        }
        .background(SongrTheme.bg)
    }
}

private struct AlbumBrowseRow: Identifiable {
    let id: String
    let heading: String?
    let albums: [Album]
}

/// One artist's albums — pushed from the artists list; `.ctx` back row on
/// top, then the shared grid.
struct ArtistAlbumsView: View {
    @EnvironmentObject private var model: AppModel
    let artist: Artist

    var body: some View {
        let albums = model.albums(forArtist: artist.id)
        VStack(spacing: 0) {
            SongrContextRow(
                title: artist.name,
                fact: "\(albums.count) \(albums.count == 1 ? "album" : "albums")"
            )
            ScrollView {
                AlbumGrid(albums: albums)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
            }
        }
        .background(SongrTheme.bg)
    }
}

/// `.tiles` — adaptive columns keep portrait and landscape both correct.
struct AlbumGrid: View {
    let albums: [Album]

    private let columns = [GridItem(.adaptive(minimum: 116, maximum: 190),
                                    spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(albums) { album in
                NavigationLink(value: album) {
                    AlbumTile(album: album)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// `.tile` — art (`.art`: 4pt radius, hairline ring, soft drop), `.tt`
/// title (two lines max), `.ta` artist (muted, one line).
struct AlbumTile: View {
    let album: Album
    var reservesTitleSpace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteArtwork(path: album.thumbPath, monogram: album.title)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
            Text(album.title)
                .font(SongrTheme.font(13, .demiBold))
                .foregroundStyle(SongrTheme.textHigh)
                .lineLimit(2, reservesSpace: reservesTitleSpace)
                .multilineTextAlignment(.leading)
                .padding(.top, 8)
            Text(album.artistName)
                .font(SongrTheme.font(11.5))
                .foregroundStyle(SongrTheme.soft)
                .lineLimit(1)
                .padding(.top, 2)
        }
    }
}
