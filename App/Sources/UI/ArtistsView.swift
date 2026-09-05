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

/// One touch index in its own gutter, shared by Artists, Albums, and Genres.
/// Tap or slide to jump; a magnified letter makes short layouts usable without
/// wrapping the alphabet over the content (owner approval, 2026-09-04).
struct AlphaJumpRail: View {
    let activeTitles: Set<String>
    let onSelect: (String) -> Void

    private let titles = CatalogIndexer.sectionTitles
    private let railWidth: CGFloat = 44
    private let verticalPadding: CGFloat = 8

    @GestureState private var isInteracting = false
    @State private var scrubTitle: String?
    @State private var selectedTitle: String?
    @State private var feedback = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geometry in
            let height = max(geometry.size.height, 1)
            let cellHeight = indexHeight(height) / CGFloat(titles.count)
            VStack(spacing: 0) {
                ForEach(titles, id: \.self) { title in
                    Text(title)
                        .font(SongrTheme.font(min(13, max(1, cellHeight - 1)), .demiBold))
                        .foregroundStyle(letterColor(title))
                        .frame(width: railWidth, height: cellHeight)
                }
            }
            .padding(.vertical, verticalPadding)
            .frame(width: railWidth, height: height, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isInteracting) { _, interacting, _ in
                        interacting = true
                    }
                    .onChanged { value in
                        scrub(at: value.location.y, height: height)
                    }
                    .onEnded { value in
                        scrub(at: value.location.y, height: height)
                        scrubTitle = nil
                    }
            )
            .overlay(alignment: .topLeading) {
                if isInteracting, let title = scrubTitle,
                   let index = titles.firstIndex(of: title) {
                    let centerY = verticalPadding + (CGFloat(index) + 0.5) * cellHeight
                    Text(title)
                        .font(SongrTheme.font(36, .demiBold))
                        .foregroundStyle(activeTitles.contains(title) ? SongrTheme.text : SongrTheme.soft)
                        .frame(width: 64, height: 64)
                        .background(SongrTheme.raise, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(SongrTheme.lineStrong, lineWidth: 1)
                        }
                        .shadow(color: SongrTheme.shadow, radius: 8, y: 3)
                        .position(x: railWidth + 44,
                                  y: min(max(centerY, 32), max(height - 32, 32)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: isInteracting) { _, interacting in
                // Gesture cancellation must dismiss the bubble too.
                if !interacting { scrubTitle = nil }
            }
            .onChange(of: height) { _, _ in scrubTitle = nil }
        }
        .frame(width: railWidth)
        .background(SongrTheme.rail)
        .allowsHitTesting(!activeTitles.isEmpty)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alphabetical index")
        .accessibilityValue(selectedTitle ?? availableTitles.first ?? "")
        .accessibilityHint("Swipe up or down to jump between letters.")
        .accessibilityAdjustableAction { direction in
            let available = availableTitles
            guard !available.isEmpty else { return }
            let current = selectedTitle.flatMap { available.firstIndex(of: $0) }
            switch direction {
            case .increment:
                select(available[min((current ?? -1) + 1, available.count - 1)])
            case .decrement:
                select(available[max((current ?? available.count) - 1, 0)])
            @unknown default:
                break
            }
        }
        .accessibilityHidden(activeTitles.isEmpty)
    }

    private var availableTitles: [String] {
        titles.filter { activeTitles.contains($0) }
    }

    private func indexHeight(_ height: CGFloat) -> CGFloat {
        max(height - 2 * verticalPadding, 1)
    }

    private func letterColor(_ title: String) -> Color {
        if !activeTitles.contains(title) { return SongrTheme.disabled }
        return isInteracting && scrubTitle == title ? SongrTheme.accentBright : SongrTheme.soft
    }

    private func scrub(at y: CGFloat, height: CGFloat) {
        let fraction = min(max((y - verticalPadding) / indexHeight(height), 0), 1)
        let index = min(Int(fraction * CGFloat(titles.count)), titles.count - 1)
        let title = titles[index]
        guard title != scrubTitle else { return }
        if scrubTitle == nil { feedback.prepare() }
        scrubTitle = title
        select(title)
    }

    private func select(_ title: String) {
        guard activeTitles.contains(title) else { return }
        selectedTitle = title
        feedback.selectionChanged()
        onSelect(title)
    }
}
