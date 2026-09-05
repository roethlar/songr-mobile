import Foundation

public enum CatalogSortDirection: String, CaseIterable, Sendable {
    case ascending, descending
}

public enum CatalogSortField: String, CaseIterable, Sendable {
    case name, artist, year, dateAdded, lastPlayed, playCount, albumCount

    public static let artistFields: [Self] = [.name, .albumCount]
    public static let albumFields: [Self] = [.name, .artist, .year, .dateAdded, .lastPlayed, .playCount]

    public var defaultDirection: CatalogSortDirection {
        self == .name || self == .artist ? .ascending : .descending
    }
}

/// Sort the complete catalog, not a capped recency shelf. Missing metadata
/// stays last in both directions; names and IDs make equal values stable.
public enum CatalogOrdering {
    public static func artists(_ artists: [Artist], by field: CatalogSortField,
                               direction: CatalogSortDirection) -> [Artist] {
        artists.sorted { a, b in
            let primary: Bool?
            if field == .albumCount {
                primary = before(a.albumCount, b.albumCount, direction: direction)
            } else {
                primary = before(CatalogIndexer.sortKey(a.name), CatalogIndexer.sortKey(b.name),
                                 direction: direction)
            }
            return primary ?? tie(a.name, a.id, b.name, b.id)
        }
    }

    public static func albums(_ albums: [Album], by field: CatalogSortField,
                              direction: CatalogSortDirection) -> [Album] {
        albums.sorted { a, b in
            let primary: Bool?
            switch field {
            case .artist:
                primary = before(CatalogIndexer.sortKey(a.artistName), CatalogIndexer.sortKey(b.artistName),
                                 direction: direction)
            case .year: primary = before(a.year, b.year, direction: direction)
            case .dateAdded: primary = before(a.addedAt, b.addedAt, direction: direction)
            case .lastPlayed: primary = before(a.lastPlayedAt, b.lastPlayedAt, direction: direction)
            case .playCount: primary = before(a.playCount, b.playCount, direction: direction)
            default:
                primary = before(CatalogIndexer.sortKey(a.title), CatalogIndexer.sortKey(b.title),
                                 direction: direction)
            }
            return primary ?? tie(a.title, a.id, b.title, b.id)
        }
    }

    /// Section an already ordered catalog without sorting its contents again.
    /// Used only for name/artist sorts; numeric/date orders remain continuous.
    public static func alphabeticalSections<Element: Hashable & Sendable>(
        _ items: [Element], name: (Element) -> String,
        direction: CatalogSortDirection
    ) -> [CatalogSection<Element>] {
        let grouped = Dictionary(grouping: items) { CatalogIndexer.sectionTitle(for: name($0)) }
        let letters = CatalogIndexer.sectionTitles.filter { $0 != "#" }
        let titles = (direction == .ascending ? letters : Array(letters.reversed())) + ["#"]
        return titles.compactMap { title in
            grouped[title].map { CatalogSection(title: title, items: $0) }
        }
    }

    /// A nonalphabetical view's rail finds the first matching item in the
    /// displayed order. UI code maps that index to its concrete visual row.
    public static func firstLetterIndices<Element>(_ items: [Element],
                                                    name: (Element) -> String) -> [String: Int] {
        var indices: [String: Int] = [:]
        for (index, item) in items.enumerated() {
            let letter = CatalogIndexer.sectionTitle(for: name(item))
            if indices[letter] == nil { indices[letter] = index }
        }
        return indices
    }

    private static func before<T: Comparable>(_ a: T?, _ b: T?,
                                              direction: CatalogSortDirection) -> Bool? {
        switch (a, b) {
        case let (a?, b?):
            guard a != b else { return nil }
            return direction == .ascending ? a < b : a > b
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return nil
        }
    }

    private static func tie(_ a: String, _ aID: String, _ b: String, _ bID: String) -> Bool {
        let left = CatalogIndexer.sortKey(a), right = CatalogIndexer.sortKey(b)
        if left != right { return left < right }
        if a != b { return a < b }
        return aID < bID
    }
}
