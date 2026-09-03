import SongrKit
import SwiftUI

/// Albums scope: the whole library as an artwork grid, A→Z with the web's
/// `.gl` letter headings and the same letter rail as the artists scope
/// (the web rail indexes whichever list is on screen). Tiles are the web's
/// `.tile`: square art, 4pt radius, title under, artist muted.
struct AlbumsGridView: View {
    @EnvironmentObject private var model: AppModel

    private var sections: [CatalogSection<Album>] {
        model.snapshot?.albumSections() ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                AlphaJumpRail(activeTitles: Set(sections.map(\.title))) { title in
                    proxy.scrollTo(anchor(title), anchor: .top)
                }
                .zIndex(1)  // the scrub bubble rides over the grid
                Rectangle().fill(SongrTheme.line).frame(width: 1)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sections, id: \.title) { section in
                            SongrGroupHeading(title: section.title)
                                .id(anchor(section.title))
                                .padding(.bottom, 4)
                            AlbumGrid(albums: section.items)
                                .padding(.bottom, 10)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
                .refreshable { await model.refreshCatalog() }
            }
            .background(SongrTheme.bg)
        }
    }

    private func anchor(_ title: String) -> String { "albums-\(title)" }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteArtwork(path: album.thumbPath, monogram: album.title)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
            Text(album.title)
                .font(SongrTheme.font(13, .demiBold))
                .foregroundStyle(SongrTheme.textHigh)
                .lineLimit(2)
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
