import CarPlay
import Combine
import SongrKit
import UIKit

/// The CarPlay face of songr: a tab bar with Artists / Albums / Now Playing.
/// - Artists: ONE continuous list, A–Z sections with the letter index rail
///   (no letter drill-down), rows "name — N albums".
/// - Albums: artwork rows (CPListImageRowItem) grouped by letter; tapping a
///   cover opens the track list; tapping a track plays from that track.
/// Section/batching math lives in SongrKit's CarPlayBrowsePlan (unit-tested);
/// this class only maps plans onto CarPlay templates.
@MainActor
final class CarPlayBrowseController {
    private let interfaceController: CPInterfaceController
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []

    private let artistsList = CPListTemplate(title: "Artists", sections: [])
    private let albumsList = CPListTemplate(title: "Albums", sections: [])
    /// Bumped on every rebuild so stale artwork loads stop touching templates.
    private var artworkGeneration = 0

    private var rowBatchSize: Int { Int(CPMaximumNumberOfGridImages) }
    /// TEMP gallery state — DELETE with gallery extension below.
    fileprivate var lastSnapshot: CatalogSnapshot? {
        get { _lastSnapshot }
        set { _lastSnapshot = newValue }
    }
    private var _lastSnapshot: CatalogSnapshot?
    fileprivate var galleryCommand = ""

    init(interfaceController: CPInterfaceController, model: AppModel) {
        self.interfaceController = interfaceController
        self.model = model
    }

    func makeRootTemplate() -> CPTemplate {
        artistsList.tabTitle = "Artists"
        artistsList.tabImage = UIImage(systemName: "music.mic")
        artistsList.emptyViewTitleVariants = ["Artists"]
        artistsList.emptyViewSubtitleVariants = ["Waiting for your library…"]
        albumsList.tabTitle = "Albums"
        albumsList.tabImage = UIImage(systemName: "square.grid.2x2")
        albumsList.emptyViewTitleVariants = ["Albums"]
        albumsList.emptyViewSubtitleVariants = ["Waiting for your library…"]

        // CPNowPlayingTemplate is NOT a legal tab-bar child (CarPlay throws in
        // validateTemplates:). It is pushed on play instead, and the system
        // list templates surface the standard now-playing button on their own.
        NSLog("[carplay] caps items=%d sections=%d imagesPerRow=%d",
              CPListTemplate.maximumItemCount, CPListTemplate.maximumSectionCount,
              CPListImageRowItem.maximumImageSize.width > 0 ? 4 : 4)
        model.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.rebuild(with: snapshot)
            }
            .store(in: &cancellables)

#if DEBUG
        registerGalleryHook()
#endif
        return CPTabBarTemplate(templates: [artistsList, albumsList])
    }

    // MARK: Artists tab

    private func rebuild(with snapshot: CatalogSnapshot?) {
        artworkGeneration += 1
        guard let snapshot else {
            artistsList.updateSections([])
            albumsList.updateSections([])
            return
        }
        lastSnapshot = snapshot
        rebuildArtists(snapshot)
        rebuildAlbums(snapshot)
    }

    private func rebuildArtists(_ snapshot: CatalogSnapshot) {
        let plan = CarPlayBrowsePlan.artistSections(snapshot.artists)
        guard #available(iOS 26.0, *) else {
            rebuildArtistsLegacy(plan)
            return
        }
        let sections = plan.prefix(Int(CPListTemplate.maximumSectionCount)).map { section -> CPListSection in
            let artists = section.artists
            let elements = artists.map { artist in
                CPListImageRowItemCondensedElement(
                    image: Self.blankTile,
                    imageShape: .roundedRectangle,
                    title: artist.name,
                    subtitle: CarPlayBrowsePlan.artistDetailText(albumCount: artist.albumCount),
                    accessorySymbolName: "chevron.right")
            }
            let item = CPListImageRowItem(text: nil,
                                          condensedElements: elements,
                                          allowsMultipleLines: true)
            item.listImageRowHandler = { [weak self] _, index, completion in
                guard let self, artists.indices.contains(index) else { return completion() }
                self.pushArtistAlbums(artists[index])
                completion()
            }
            return CPListSection(items: [item],
                                 header: section.indexTitle,
                                 sectionIndexTitle: section.indexTitle)
        }
        artistsList.updateSections(Array(sections))
    }

    /// Pre-iOS 26 fallback (condensed image-row elements don't exist there):
    /// plain indexed rows, clamped to the head-unit item budget.
    private func rebuildArtistsLegacy(_ plan: [CarPlayBrowsePlan.ArtistSection]) {
        var itemBudget = Int(CPListTemplate.maximumItemCount)
        var sections: [CPListSection] = []
        for section in plan.prefix(Int(CPListTemplate.maximumSectionCount)) {
            guard itemBudget > 0 else { break }
            let items = section.artists.prefix(itemBudget).map { artist -> CPListItem in
                let item = CPListItem(
                    text: artist.name,
                    detailText: CarPlayBrowsePlan.artistDetailText(albumCount: artist.albumCount)
                )
                item.accessoryType = .disclosureIndicator
                item.handler = { [weak self] _, completion in
                    guard let self else { return completion() }
                    self.pushArtistAlbums(artist)
                    completion()
                }
                return item
            }
            itemBudget -= items.count
            sections.append(CPListSection(items: items,
                                          header: section.indexTitle,
                                          sectionIndexTitle: section.indexTitle))
        }
        artistsList.updateSections(sections)
    }

    private func pushArtistAlbums(_ artist: Artist) {
        let albums = model.albums(forArtist: artist.id)
        let items: [CPListTemplateItem]
        if #available(iOS 26.0, *) {
            items = [gridItem(for: albums)]
        } else {
            items = CarPlayBrowsePlan.imageRowBatches(albums, batchSize: rowBatchSize)
                .map { imageRowItem(for: $0) }
        }
        let template = CPListTemplate(title: artist.name, sections: [
            CPListSection(items: items)
        ])
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: Albums tab

    private func rebuildAlbums(_ snapshot: CatalogSnapshot) {
        guard #available(iOS 26.0, *) else {
            rebuildAlbumsLegacy(snapshot)
            return
        }
        let plan = CarPlayBrowsePlan.albumSections(
            snapshot.albums,
            batchSize: Int.max,
            maximumRows: Int.max
        )
        let sections = plan.prefix(Int(CPListTemplate.maximumSectionCount)).map { section -> CPListSection in
            let albums = section.rows.flatMap { $0 }
            return CPListSection(items: [gridItem(for: albums)],
                                 header: section.indexTitle,
                                 sectionIndexTitle: section.indexTitle)
        }
        albumsList.updateSections(Array(sections))
    }

    /// Pre-iOS 26 fallback: the batched cover rows from before the grid API.
    private func rebuildAlbumsLegacy(_ snapshot: CatalogSnapshot) {
        let plan = CarPlayBrowsePlan.albumSections(
            snapshot.albums,
            batchSize: rowBatchSize,
            maximumRows: Int(CPListTemplate.maximumItemCount)
        )
        let sections = plan.prefix(Int(CPListTemplate.maximumSectionCount)).map { section in
            CPListSection(items: section.rows.map { self.imageRowItem(for: $0) },
                          header: section.indexTitle,
                          sectionIndexTitle: section.indexTitle)
        }
        albumsList.updateSections(Array(sections))
    }

    // MARK: Cover rows

    /// Pre-iOS 26 cover row: batch of covers, "First – Last" caption.
    private func imageRowItem(for batch: [Album]) -> CPListImageRowItem {
        let item = CPListImageRowItem(text: Self.rowText(for: batch),
                                      images: batch.map { Self.monogramCover(for: $0.title) })
        item.listImageRowHandler = { [weak self] _, index, completion in
            guard let self, batch.indices.contains(index) else { return completion() }
            self.pushTrackList(for: batch[index])
            completion()
        }
        item.handler = { _, completion in completion() }
        loadCovers(for: batch, into: item)
        return item
    }

    /// "First Title – Last Title" so a cover row reads like a range.
    private static func rowText(for batch: [Album]) -> String {
        guard let first = batch.first else { return "" }
        guard batch.count > 1, let last = batch.last else { return first.title }
        return "\(first.title) – \(last.title)"
    }

    private func loadCovers(for batch: [Album], into item: CPListImageRowItem) {
        let generation = artworkGeneration
        let side = Int(max(CPListImageRowItem.maximumImageSize.width, 120))
        Task { [weak self, weak item] in
            var images: [UIImage] = []
            var loadedAny = false
            for album in batch {
                guard let self, self.artworkGeneration == generation else { return }
                if let cover = await self.model.artwork(path: album.thumbPath,
                                                        pixels: side) {
                    images.append(cover)
                    loadedAny = true
                } else {
                    images.append(Self.monogramCover(for: album.title))
                }
            }
            guard let self, self.artworkGeneration == generation,
                  loadedAny, let item else { return }
            item.update(images)
        }
    }

    @available(iOS 26.0, *)
    private func gridItem(for albums: [Album]) -> CPListImageRowItem {
        let elements = albums.map {
            CPListImageRowItemGridElement(image: Self.monogramCover(for: $0.title))
        }
        let item = CPListImageRowItem(text: nil,
                                      gridElements: elements,
                                      allowsMultipleLines: true)
        item.listImageRowHandler = { [weak self] _, index, completion in
            guard let self, albums.indices.contains(index) else { return completion() }
            self.pushTrackList(for: albums[index])
            completion()
        }
        loadCovers(for: albums, into: elements)
        return item
    }

    @available(iOS 26.0, *)
    private func loadCovers(for albums: [Album], into elements: [CPListImageRowItemGridElement]) {
        let generation = artworkGeneration
        let side = Int(max(CPListImageRowItemGridElement.maximumImageSize.width, 120))
        Task { [weak self] in
            for (i, album) in albums.enumerated() {
                guard let self, self.artworkGeneration == generation else { return }
                if let cover = await self.model.artwork(path: album.thumbPath,
                                                        pixels: side) {
                    elements[i].image = cover
                }
            }
        }
    }

    /// Flat songr-surface tile so condensed artist elements read as plain
    /// text-on-background rows, like the songr artist list.
    private static let blankTile: UIImage = {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        return r.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }()

    /// Songr `.mono-tile` at car scale: the album's initial on the songr
    /// surface (#111) with the gold accent (#c8a24a) — the CarPlay face of
    /// the same placeholder the phone grid shows. Cached per letter.
    private static var monogramCache: [String: UIImage] = [:]

    static func monogramCover(for title: String) -> UIImage {
        let letter = title.trimmingCharacters(in: .whitespaces).first
            .map { String($0).uppercased() } ?? "♪"
        if let cached = monogramCache[letter] { return cached }
        let size = CGSize(width: 180, height: 180)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0x11 / 255.0, green: 0x11 / 255.0,
                    blue: 0x11 / 255.0, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let gold = UIColor(red: 0xC8 / 255.0, green: 0xA2 / 255.0,
                               blue: 0x4A / 255.0, alpha: 0.9)
            let font = UIFont(name: "AvenirNext-DemiBold", size: 72)
                ?? UIFont.systemFont(ofSize: 72, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: gold,
            ]
            let text = NSAttributedString(string: letter, attributes: attributes)
            let bounds = text.boundingRect(with: size, options: [], context: nil)
            text.draw(at: CGPoint(x: (size.width - bounds.width) / 2,
                                  y: (size.height - bounds.height) / 2))
        }
        monogramCache[letter] = image
        return image
    }

    // MARK: Track list → play

    private func pushTrackList(for album: Album) {
        let template = CPListTemplate(title: album.title, sections: [])
        template.emptyViewTitleVariants = [album.title]
        template.emptyViewSubtitleVariants = ["Loading…"]
        interfaceController.pushTemplate(template, animated: true, completion: nil)
        Task { [weak self] in
            guard let self else { return }
            guard let tracks = try? await self.model.tracks(for: album),
                  !tracks.isEmpty else {
                template.emptyViewSubtitleVariants = ["Couldn't load tracks"]
                return
            }
            let items = tracks.enumerated().map { index, track in
                self.trackItem(album: album, tracks: tracks,
                               track: track, index: index)
            }
            template.updateSections([CPListSection(items: items)])
        }
    }

    private func trackItem(album: Album, tracks: [Track],
                           track: Track, index: Int) -> CPListItem {
        let detail = track.durationMs.map { ms -> String in
            let seconds = ms / 1000
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        let item = CPListItem(text: "\(track.trackNumber). \(track.title)",
                              detailText: detail)
        item.handler = { [weak self] _, completion in
            guard let self else { return completion() }
            self.model.play(album: album, tracks: tracks, startAt: index)
            self.interfaceController.pushTemplate(CPNowPlayingTemplate.shared,
                                                  animated: true, completion: nil)
            completion()
        }
        return item
    }
}

// MARK: - TEMP template gallery (DEBUG only; driven by <app-tmp>/gallery.txt) — DELETE
#if DEBUG
extension CarPlayBrowseController {
    func registerGalleryHook() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gallery.txt")
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let raw = (try? String(contentsOf: url, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let raw, !raw.isEmpty else { return }
            Task { @MainActor [weak self] in
                guard let self, raw != self.galleryCommand else { return }
                self.galleryCommand = raw
                if raw.hasPrefix("lib=") {
                    self.model.debugSelectLibrary(titled: String(raw.dropFirst(4)))
                } else if let v = Int(raw) {
                    self.showGalleryVariant(v)
                }
            }
        }
    }

    private func showGalleryVariant(_ v: Int) {
        guard let snap = lastSnapshot else { NSLog("[gallery] no snapshot yet"); return }
        let template: CPTemplate
        switch v {
        case 0: template = galleryArtistsPlain(snap)
        case 1:
            guard #available(iOS 26.0, *) else { return }
            template = galleryArtistsCards(snap)
        case 2: template = galleryAlbumsPlain(snap)
        case 3:
            guard #available(iOS 26.0, *) else { return }
            template = galleryAlbumsCards(snap)
        case 4:
            guard #available(iOS 26.0, *) else { return }
            template = galleryAlbumsGrid(snap)
        case 5: template = galleryLetterGrid()
        default: return
        }
        NSLog("[gallery] showing variant %d", v)
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
    }

    private func galleryArtistsPlain(_ snap: CatalogSnapshot) -> CPTemplate {
        let plan = CarPlayBrowsePlan.artistSections(snap.artists)
        var budget = Int(CPListTemplate.maximumItemCount)
        var sections: [CPListSection] = []
        for section in plan.prefix(Int(CPListTemplate.maximumSectionCount)) {
            guard budget > 0 else { break }
            let artists = Array(section.artists.prefix(budget))
            budget -= artists.count
            let items = artists.map { artist -> CPListItem in
                let item = CPListItem(
                    text: artist.name,
                    detailText: CarPlayBrowsePlan.artistDetailText(albumCount: artist.albumCount),
                    image: nil, accessoryImage: nil,
                    accessoryType: .disclosureIndicator)
                item.handler = { [weak self] _, completion in
                    self?.pushArtistAlbums(artist)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: items,
                                          header: section.indexTitle,
                                          sectionIndexTitle: section.indexTitle))
        }
        return CPListTemplate(title: "0 · Artists — rows", sections: sections)
    }

    @available(iOS 26.0, *)
    private func galleryArtistsCards(_ snap: CatalogSnapshot) -> CPTemplate {
        let plan = CarPlayBrowsePlan.artistSections(snap.artists)
        let sections = plan.prefix(Int(CPListTemplate.maximumSectionCount)).map { section -> CPListSection in
            let artists = section.artists
            let elements = artists.map { artist in
                CPListImageRowItemCondensedElement(
                    image: Self.blankTile,
                    imageShape: .roundedRectangle,
                    title: artist.name,
                    subtitle: CarPlayBrowsePlan.artistDetailText(albumCount: artist.albumCount),
                    accessorySymbolName: "chevron.right")
            }
            let item = CPListImageRowItem(text: nil,
                                          condensedElements: elements,
                                          allowsMultipleLines: true)
            item.listImageRowHandler = { [weak self] _, index, completion in
                guard let self, artists.indices.contains(index) else { return completion() }
                self.pushArtistAlbums(artists[index])
                completion()
            }
            return CPListSection(items: [item],
                                 header: section.indexTitle,
                                 sectionIndexTitle: section.indexTitle)
        }
        return CPListTemplate(title: "1 · Artists — cards", sections: Array(sections))
    }

    private func galleryAlbumsPlain(_ snap: CatalogSnapshot) -> CPTemplate {
        let plan = CarPlayBrowsePlan.albumSections(snap.albums, batchSize: Int.max, maximumRows: Int.max)
        var budget = Int(CPListTemplate.maximumItemCount)
        var sections: [CPListSection] = []
        var warm: [(Album, CPListItem)] = []
        for section in plan.prefix(Int(CPListTemplate.maximumSectionCount)) {
            guard budget > 0 else { break }
            let albums = Array(section.rows.flatMap { $0 }.prefix(budget))
            budget -= albums.count
            let items = albums.map { album -> CPListItem in
                let item = CPListItem(
                    text: album.title,
                    detailText: album.artistName,
                    image: Self.monogramCover(for: album.title),
                    accessoryImage: nil,
                    accessoryType: .disclosureIndicator)
                item.handler = { [weak self] _, completion in
                    self?.pushTrackList(for: album)
                    completion()
                }
                return item
            }
            if warm.count < 20 { warm.append(contentsOf: zip(albums, items).prefix(20 - warm.count)) }
            sections.append(CPListSection(items: items,
                                          header: section.indexTitle,
                                          sectionIndexTitle: section.indexTitle))
        }
        let generation = artworkGeneration
        Task { [weak self] in
            for (album, item) in warm {
                guard let self, self.artworkGeneration == generation else { return }
                if let cover = await self.model.artwork(path: album.thumbPath, pixels: 180) {
                    item.setImage(cover)
                }
            }
        }
        return CPListTemplate(title: "2 · Albums — rows", sections: sections)
    }

    @available(iOS 26.0, *)
    private func galleryAlbumsCards(_ snap: CatalogSnapshot) -> CPTemplate {
        let plan = CarPlayBrowsePlan.albumSections(snap.albums, batchSize: Int.max, maximumRows: Int.max)
        var warm: [(Album, CPListImageRowItemCondensedElement)] = []
        let sections = plan.prefix(Int(CPListTemplate.maximumSectionCount)).map { section -> CPListSection in
            let albums = section.rows.flatMap { $0 }
            let elements = albums.map { album in
                CPListImageRowItemCondensedElement(
                    image: Self.monogramCover(for: album.title),
                    imageShape: .roundedRectangle,
                    title: album.title,
                    subtitle: album.artistName,
                    accessorySymbolName: "chevron.right")
            }
            if warm.count < 20 { warm.append(contentsOf: zip(albums, elements).prefix(20 - warm.count)) }
            let item = CPListImageRowItem(text: nil,
                                          condensedElements: elements,
                                          allowsMultipleLines: true)
            item.listImageRowHandler = { [weak self] _, index, completion in
                guard let self, albums.indices.contains(index) else { return completion() }
                self.pushTrackList(for: albums[index])
                completion()
            }
            return CPListSection(items: [item],
                                 header: section.indexTitle,
                                 sectionIndexTitle: section.indexTitle)
        }
        let generation = artworkGeneration
        Task { [weak self] in
            for (album, element) in warm {
                guard let self, self.artworkGeneration == generation else { return }
                if let cover = await self.model.artwork(path: album.thumbPath, pixels: 180) {
                    element.image = cover
                }
            }
        }
        return CPListTemplate(title: "3 · Albums — cards", sections: Array(sections))
    }

    @available(iOS 26.0, *)
    private func galleryAlbumsGrid(_ snap: CatalogSnapshot) -> CPTemplate {
        let plan = CarPlayBrowsePlan.albumSections(snap.albums, batchSize: Int.max, maximumRows: Int.max)
        let sections = plan.prefix(Int(CPListTemplate.maximumSectionCount)).map { section -> CPListSection in
            let albums = section.rows.flatMap { $0 }
            return CPListSection(items: [gridItem(for: albums)],
                                 header: section.indexTitle,
                                 sectionIndexTitle: section.indexTitle)
        }
        return CPListTemplate(title: "4 · Albums — cover grid", sections: Array(sections))
    }

    private func galleryLetterGrid() -> CPTemplate {
        let groups = ["ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ#"]
        let buttons = groups.map { group -> CPGridButton in
            let label = group.map(String.init).joined(separator: " ")
            return CPGridButton(titleVariants: [label],
                                image: Self.monogramCover(for: String(group.first ?? "A"))) { _ in }
        }
        return CPGridTemplate(title: "5 · Letter launcher", gridButtons: buttons)
    }
}
#endif
