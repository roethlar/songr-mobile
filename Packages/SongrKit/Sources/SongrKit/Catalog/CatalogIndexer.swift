import Foundation

/// One A–Z (or "#") slice of the catalog.
public struct CatalogSection<Element: Sendable & Hashable>: Sendable, Hashable {
    /// "A"…"Z" or "#" (numbers/symbols; sorts after Z, Contacts-style).
    public let title: String
    public let items: [Element]

    public init(title: String, items: [Element]) {
        self.title = title
        self.items = items
    }
}

/// Pure A–Z sectioning + sorting shared by the phone UI and the CarPlay
/// browse plan, sized for the owner's library (~2000 artists / ~4000 albums).
public enum CatalogIndexer {
    public static let sectionTitles: [String] =
        (UnicodeScalar("A").value...UnicodeScalar("Z").value)
            .compactMap { UnicodeScalar($0).map(String.init) } + ["#"]

    /// Case/diacritic-folded key used for sorting and letter assignment.
    public static func sortKey(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "en_US"))
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "A"…"Z" for names starting with a letter, else "#".
    public static func sectionTitle(for name: String) -> String {
        guard let first = sortKey(name).unicodeScalars.first else { return "#" }
        let letters = CharacterSet(charactersIn: "A"..."Z")
        return letters.contains(first) ? String(first) : "#"
    }

    /// Groups pre-labeled items into A–Z + # sections, dropping empty letters,
    /// with "#" last. Items are sorted case/diacritic-insensitively by name.
    public static func sections<Element: Sendable & Hashable>(
        of items: [Element],
        name: (Element) -> String
    ) -> [CatalogSection<Element>] {
        let sorted = items.sorted {
            let (a, b) = (sortKey(name($0)), sortKey(name($1)))
            return a == b ? name($0) < name($1) : a < b
        }
        let grouped = Dictionary(grouping: sorted) { sectionTitle(for: name($0)) }
        return sectionTitles.compactMap { title in
            grouped[title].map { CatalogSection(title: title, items: $0) }
        }
    }
}

/// The full cached artist/album index. Fetched once, persisted, refreshed on
/// demand — browsing never waits on the server after the first sync.
public struct CatalogSnapshot: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var artists: [Artist]
    public var albums: [Album]

    public init(generatedAt: Date, artists: [Artist], albums: [Album]) {
        self.generatedAt = generatedAt
        self.artists = artists
        self.albums = albums
    }

    /// Builds a snapshot with per-artist album counts recomputed from the
    /// album index (authoritative — Plex artist listings may omit counts).
    public static func build(generatedAt: Date = Date(),
                             artists: [Artist],
                             albums: [Album]) -> CatalogSnapshot {
        let counts = Dictionary(grouping: albums, by: \.artistID)
            .mapValues(\.count)
        let counted = artists.map { artist in
            Artist(id: artist.id, name: artist.name,
                   albumCount: counts[artist.id] ?? artist.albumCount,
                   thumbPath: artist.thumbPath)
        }
        return CatalogSnapshot(generatedAt: generatedAt,
                               artists: counted, albums: albums)
    }

    public func artistSections() -> [CatalogSection<Artist>] {
        CatalogIndexer.sections(of: artists, name: \.name)
    }

    public func albumSections() -> [CatalogSection<Album>] {
        CatalogIndexer.sections(of: albums, name: \.title)
    }

    /// An artist's albums, oldest first (year, then title), like songr.
    public func albums(forArtist artistID: String) -> [Album] {
        albums
            .filter { $0.artistID == artistID }
            .sorted {
                let (a, b) = ($0.year ?? Int.max, $1.year ?? Int.max)
                return a == b
                    ? CatalogIndexer.sortKey($0.title) < CatalogIndexer.sortKey($1.title)
                    : a < b
            }
    }
}
