// Native CarPlay layout comparison only. Not part of the shipping target.
import CarPlay
import Combine
import SongrKit
import UIKit

@MainActor
final class CarPlayBrowseController {
    private let interfaceController: CPInterfaceController
    private let model: AppModel
    private var subscription: AnyCancellable?
    private let artists = CPListTemplate(title: "Artists", sections: [])
    private let albums = CPListTemplate(title: "Albums", sections: [])
    private var root: CPTabBarTemplate!
    private let option = UIPreviewHarness.value(after: "-SongrCarPlayOption") ?? "A"

    init(interfaceController: CPInterfaceController, model: AppModel) {
        self.interfaceController = interfaceController
        self.model = model
    }

    func makeRootTemplate() -> CPTemplate {
        artists.tabTitle = "Artists"
        artists.tabImage = UIImage(systemName: "music.mic")
        albums.tabTitle = "Albums"
        albums.tabImage = UIImage(systemName: "square.grid.2x2")
        albums.emptyViewTitleVariants = ["Preparing comparison"]
        root = CPTabBarTemplate(templates: [artists, albums])
        subscription = model.$snapshot.compactMap { $0 }.filter { !$0.albums.isEmpty }.first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                Task { await self.populate(snapshot) }
            }
        return root
    }

    private func populate(_ snapshot: CatalogSnapshot) async {
        guard #available(iOS 26.0, *) else { return }
        let sections = CatalogIndexer.sections(of: snapshot.albums, name: \.title)
        let sample = Array((sections.first { $0.title == "A" }?.items ?? snapshot.albums).prefix(12))
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CarPlayOptionProofs", isDirectory: true)
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        var covers: [UIImage] = []
        for album in sample {
            let file = cache.appendingPathComponent("cover-\(album.id).png")
            if let image = UIImage(contentsOfFile: file.path) {
                covers.append(image)
            } else if let image = await model.artwork(path: album.thumbPath, pixels: 240) {
                covers.append(image)
                try? image.pngData()?.write(to: file, options: .atomic)
            } else {
                covers.append(Self.placeholder(album.title))
            }
        }
        var items: [CPListTemplateItem] = []
        switch option {
        case "A", "B":
            items = sample.enumerated().map { index, album in
                let item = CPListItem(text: album.title, detailText: album.artistName,
                                      image: option == "B" ? covers[index] : nil)
                item.accessoryType = .disclosureIndicator
                item.handler = { _, completion in completion() }
                return item
            }
        case "C":
            let elements = sample.enumerated().map { index, album in
                CPListImageRowItemCondensedElement(image: covers[index], imageShape: .roundedRectangle,
                    title: album.title, subtitle: album.artistName, accessorySymbolName: nil)
            }
            items = [CPListImageRowItem(text: nil, condensedElements: elements, allowsMultipleLines: true)]
        case "D":
            let elements = sample.enumerated().map { index, album in
                CPListImageRowItemRowElement(image: covers[index], title: album.title, subtitle: album.artistName)
            }
            items = [CPListImageRowItem(text: nil, elements: elements, allowsMultipleLines: true)]
        case "E", "F":
            let elements = sample.enumerated().map { index, album in
                CPListImageRowItemCardElement(image: covers[index], showsImageFullHeight: option == "F",
                    title: album.title, subtitle: album.artistName, tintColor: nil)
            }
            items = [CPListImageRowItem(text: nil, cardElements: elements, allowsMultipleLines: true)]
        case "G":
            let elements = covers.map { CPListImageRowItemGridElement(image: $0) }
            items = [CPListImageRowItem(text: nil, gridElements: elements, allowsMultipleLines: true)]
        case "H", "I":
            let elements = sample.enumerated().map { index, album in
                CPListImageRowItemImageGridElement(image: covers[index],
                    imageShape: option == "H" ? .circular : .roundedRectangle,
                    title: album.title, accessorySymbolName: nil)
            }
            items = [CPListImageRowItem(text: nil, imageGridElements: elements, allowsMultipleLines: true)]
        default: break
        }
        for case let item as CPListImageRowItem in items {
            item.listImageRowHandler = { _, _, completion in completion() }
        }
        albums.updateSections([CPListSection(items: items, header: "A", sectionIndexTitle: "A")])
        root.select(albums)
        print("carplay-option-ready \(option) sample=\(sample.count) artwork=\(covers.count) nativeItems=\(albums.itemCount)")
    }

    private static func placeholder(_ title: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240))
        return renderer.image { context in
            UIColor(white: 0.08, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            String(title.prefix(1)).draw(at: CGPoint(x: 85, y: 65), withAttributes: [
                .font: UIFont.systemFont(ofSize: 88, weight: .medium), .foregroundColor: UIColor.lightGray])
        }
    }
}
