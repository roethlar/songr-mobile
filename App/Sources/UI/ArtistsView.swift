import SongrKit
import SwiftUI

/// The Browse UX directive, in songr's own image: ONE continuous artist list
/// — every artist, A to Z then #, rows "name ····· N albums" with the dotted
/// leader from the web's `.arow`/`.ad`/`.ac`, letter group headings (`.gl`),
/// and the letter rail (`.rail`) docked on the left exactly like the web.
/// No letter drill-down.
///
/// Width decides columns the way the web's `.alist { column-count: var(--col) }`
/// does: portrait phones read one column, landscape two, wider panes three —
/// each letter group flowing top-to-bottom then across, CSS-columns order.
struct ArtistsView: View {
    @EnvironmentObject private var model: AppModel

    private var sections: [CatalogSection<Artist>] {
        model.snapshot?.artistSections() ?? []
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = Self.columnCount(for: geometry.size.width)
            ScrollViewReader { proxy in
                HStack(spacing: 0) {
                    AlphaJumpRail(activeTitles: Set(sections.map(\.title))) { title in
                        proxy.scrollTo(anchor(title), anchor: .top)
                    }
                    .zIndex(1)  // the scrub bubble rides over the list
                    Rectangle().fill(SongrTheme.line).frame(width: 1)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(sections, id: \.title) { section in
                                SongrGroupHeading(title: section.title)
                                    .id(anchor(section.title))
                                ArtistSectionColumns(items: section.items,
                                                     columns: columns)
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
    }

    /// Web `.alist` breakpoints in spirit: 1 column to phone-portrait widths
    /// (web: ≤520px), 2 beyond (web: 521–760px, then density-driven), 3 once
    /// a pane is wide enough that two columns would leave dead width.
    static func columnCount(for width: CGFloat) -> Int {
        width >= 1000 ? 3 : width >= 620 ? 2 : 1
    }

    private func anchor(_ title: String) -> String { "artists-\(title)" }
}

/// One letter group's rows in CSS-columns reading order: down the first
/// column, then the next — emitted row-by-row (each visual row is one HStack
/// of `columns` cells) so the whole list stays lazy.
private struct ArtistSectionColumns: View {
    let items: [Artist]
    let columns: Int

    var body: some View {
        let rows = (items.count + columns - 1) / columns
        ForEach(0..<rows, id: \.self) { row in
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                ForEach(0..<columns, id: \.self) { column in
                    let index = row + column * rows
                    if index < items.count {
                        NavigationLink(value: items[index]) {
                            ArtistRow(artist: items[index])
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

/// `.arow` — name, dotted leader, album count, baseline-aligned.
private struct ArtistRow: View {
    let artist: Artist

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(artist.name)
                .font(SongrTheme.font(16))
                .foregroundStyle(SongrTheme.listText)
                .lineLimit(1)
            DottedLeader()
            Text("\(artist.albumCount) \(artist.albumCount == 1 ? "album" : "albums")")
                .font(SongrTheme.font(12))
                .foregroundStyle(SongrTheme.dim)
                .lineLimit(1)
                .fixedSize()  // the count never wraps; the name truncates
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

/// `.ad` — the dotted line stretching between name and count.
struct DottedLeader: View {
    var body: some View {
        HorizontalLine()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [1.5, 3.5]))
            .foregroundStyle(SongrTheme.line13)
            .frame(height: 1)
            .frame(minWidth: 6, maxWidth: .infinity)
            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 3 }
    }

    private struct HorizontalLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// `.rail` — songr's letter index as SIMPLE, CLICKABLE LETTERS (owner
/// ruling 2026-08-31: no scrub bar, no magnifier bubble). Every letter is
/// its own full-cell-width tap target. Cells never shrink below a tappable
/// height: when one column cannot fit all 27 at `minTapHeight`, the rail
/// splits into exactly as many columns as needed (portrait: 1, phone
/// landscape: 2), letters reading top-to-bottom then across.
struct AlphaJumpRail: View {
    let activeTitles: Set<String>
    let onSelect: (String) -> Void

    private let titles = CatalogIndexer.sectionTitles
    private let columnWidth: CGFloat = 34
    /// Minimum tappable cell height; column count derives from it.
    private let minTapHeight: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            let height = max(geometry.size.height, minTapHeight)
            let rowsPerColumn = max(Int(height / minTapHeight), 1)
            let columns = max(1, Int(ceil(Double(titles.count) / Double(rowsPerColumn))))
            let rows = Int(ceil(Double(titles.count) / Double(columns)))
            let cellHeight = min(height / CGFloat(rows), 34)
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<columns, id: \.self) { column in
                    VStack(spacing: 0) {
                        ForEach(columnTitles(column, rows: rows), id: \.self) { title in
                            letterCell(title, height: cellHeight)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: CGFloat(columns) * columnWidth,
                   height: height, alignment: .top)
        }
        // Worst case (phone landscape) is two columns; reserving that width
        // keeps the parent HStack layout stable across rotation.
        .frame(width: railReservedWidth)
        .background(SongrTheme.rail)
    }

    /// Width the rail reserves from its parent: matched to the column count
    /// the height math lands on in practice — regular height (portrait) fits
    /// one column, compact height (phone landscape) needs two.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var railReservedWidth: CGFloat {
        columnWidth * (verticalSizeClass == .compact ? 2 : 1)
    }

    private func columnTitles(_ column: Int, rows: Int) -> [String] {
        let start = column * rows
        guard start < titles.count else { return [] }
        return Array(titles[start..<min(start + rows, titles.count)])
    }

    private func letterCell(_ title: String, height: CGFloat) -> some View {
        let active = activeTitles.contains(title)
        return Button {
            guard active else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            onSelect(title)
        } label: {
            Text(title)
                .font(SongrTheme.font(13, .demiBold))
                .foregroundStyle(active ? SongrTheme.soft : SongrTheme.disabled)
                .frame(width: columnWidth, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
