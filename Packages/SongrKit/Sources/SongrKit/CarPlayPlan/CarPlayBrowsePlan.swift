import Foundation

/// Pure construction plan for the CarPlay templates, so index titles and
/// image-row batching are unit-testable on macOS (the CarPlay framework is
/// iOS-only; the controller in the app maps these plans 1:1 to CPListSection
/// / CPListImageRowItem).
public enum CarPlayBrowsePlan {
    /// One lettered section of the Artists list (CPListSection with
    /// sectionIndexTitle == title).
    public struct ArtistSection: Hashable, Sendable {
        public let indexTitle: String
        public let artists: [Artist]
    }

    /// One lettered section of the Albums tab: rows of covers
    /// (CPListImageRowItem per batch).
    public struct AlbumImageRowSection: Hashable, Sendable {
        public let indexTitle: String
        public let rows: [[Album]]
    }

    /// A–Z + # sections for the single continuous Artists list.
    public static func artistSections(_ artists: [Artist]) -> [ArtistSection] {
        CatalogIndexer.sections(of: artists, name: \.name).map {
            ArtistSection(indexTitle: $0.title, artists: $0.items)
        }
    }

    /// The rail titles, in on-screen order (only non-empty letters).
    public static func indexTitles(for sections: [ArtistSection]) -> [String] {
        sections.map(\.indexTitle)
    }

    /// "Name — N albums" detail line for an artist row.
    public static func artistDetailText(albumCount: Int) -> String {
        albumCount == 1 ? "1 album" : "\(albumCount) albums"
    }

    /// Splits albums into cover rows of at most `batchSize` (the CarPlay
    /// limit is CPMaximumNumberOfGridImages; the controller passes it in).
    public static func imageRowBatches(_ albums: [Album],
                                       batchSize: Int) -> [[Album]] {
        guard batchSize > 0, !albums.isEmpty else { return [] }
        return stride(from: 0, to: albums.count, by: batchSize).map {
            Array(albums[$0..<min($0 + batchSize, albums.count)])
        }
    }

    /// Albums tab: lettered sections of batched cover rows, capped to the
    /// head unit's list-item budget (CPListTemplate.maximumItemCount) without
    /// splitting a section mid-letter unless it is the one that overflows.
    public static func albumSections(_ albums: [Album],
                                     batchSize: Int,
                                     maximumRows: Int? = nil) -> [AlbumImageRowSection] {
        var budget = maximumRows ?? Int.max
        var result: [AlbumImageRowSection] = []
        for section in CatalogIndexer.sections(of: albums, name: \.title) {
            guard budget > 0 else { break }
            let rows = imageRowBatches(section.items, batchSize: batchSize)
            let kept = Array(rows.prefix(budget))
            budget -= kept.count
            if !kept.isEmpty {
                result.append(AlbumImageRowSection(indexTitle: section.title,
                                                   rows: kept))
            }
        }
        return result
    }
}
