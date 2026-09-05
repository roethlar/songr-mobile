import CarPlay
import UIKit

@main
struct CapacityProbe {
    @MainActor static func main() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { _ in }
        func row(_ range: Range<Int>) -> CPListImageRowItem {
            let elements = range.map { index in
                CPListImageRowItemCardElement(image: image, showsImageFullHeight: false,
                    title: "Entry \(index)", subtitle: "Album count or artist", tintColor: nil)
            }
            return CPListImageRowItem(text: nil, cardElements: elements, allowsMultipleLines: true)
        }
        func roundTrip(_ item: CPListImageRowItem) throws -> Int {
            let data = try NSKeyedArchiver.archivedData(withRootObject: CPListTemplate(title: "Probe", sections: [CPListSection(items: [item])]), requiringSecureCoding: true)
            let restored = try NSKeyedUnarchiver.unarchivedObject(ofClass: CPListTemplate.self, from: data)!
            return (restored.sections[0].items[0] as! CPListImageRowItem).elements.count
        }
        let limit = Int(CPMaximumNumberOfGridImages)
        for count in [2000, 4000] {
            let oldCount = try roundTrip(row(0..<count))
            precondition(oldCount < count, "Baseline should demonstrate native truncation")
            let rows = stride(from: 0, to: count, by: limit).map { row($0..<min($0 + limit, count)) }
            let retained = try rows.map(roundTrip).reduce(0, +)
            precondition(retained == count, "Batched native rows lost entries")
            // The connected Songr scene reported 500 items; a standalone
            // process has a smaller default, so test row encoding here.
            precondition(rows.count <= 500)
            print("requested=\(count) unbatched=\(oldCount) batched=\(retained) rows=\(rows.count) elementLimit=\(limit)")
        }
    }
}
