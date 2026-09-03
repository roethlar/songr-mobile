import Foundation

/// On-device catalog cache: JSON snapshot on disk, refreshed from a
/// LibrarySource. At the owner's scale (~2000 artists / ~4000 albums) a full
/// refetch is ~20 paged requests per index — fine to run in the background
/// while the cached snapshot keeps the UI instant.
public actor CatalogStore {
    private let fileURL: URL

    public init(directory: URL, fileName: String = "catalog.json") {
        self.fileURL = directory.appendingPathComponent(fileName)
    }

    /// Last persisted snapshot, if any (nil on first run or corrupt cache).
    public func loadCached() -> CatalogSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder().decode(CatalogSnapshot.self, from: data)
    }

    /// Full refetch: artists + albums, counts recomputed, snapshot persisted.
    @discardableResult
    public func refresh(from source: LibrarySource,
                        now: Date = Date()) async throws -> CatalogSnapshot {
        async let artists = source.fetchArtists()
        async let albums = source.fetchAlbums()
        let snapshot = CatalogSnapshot.build(generatedAt: now,
                                             artists: try await artists,
                                             albums: try await albums)
        try persist(snapshot)
        return snapshot
    }

    public func persist(_ snapshot: CatalogSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
