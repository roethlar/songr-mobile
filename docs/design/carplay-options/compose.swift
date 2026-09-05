// Creates the review sheet and PDF from unedited native CarPlay captures.
// Run from this directory with an in-repo Swift module cache.
import AppKit
import CoreGraphics

struct Option: Decodable {
    let id: String
    let title: String
    let detail: String
}

let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let options = try JSONDecoder().decode([Option].self,
    from: Data(contentsOf: directory.appendingPathComponent("options.json")))
let foreground = NSColor(calibratedWhite: 0.95, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.72, alpha: 1)
let background = NSColor(calibratedWhite: 0.07, alpha: 1)

func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
           size: CGFloat, color: NSColor = foreground) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    (text as NSString).draw(in: NSRect(x: x, y: y, width: width, height: 70),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .regular),
                         .foregroundColor: color, .paragraphStyle: style])
}

func panel(_ option: Option, x: CGFloat, y: CGFloat) throws {
    label("\(option.id)  \(option.title)", x: x, y: y, width: 800, size: 30)
    guard let screenshot = NSImage(contentsOf: directory.appendingPathComponent("\(option.id).png")) else {
        throw NSError(domain: "Missing capture \(option.id)", code: 1)
    }
    screenshot.draw(in: NSRect(x: x, y: y + 50, width: 800, height: 480),
                    from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    label(option.detail, x: x, y: y + 545, width: 800, size: 24, color: secondary)
}

let width = 2544
let height = 2136
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let bitmapContext = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmapContext.cgContext, flipped: true)
bitmapContext.cgContext.translateBy(x: 0, y: CGFloat(height))
bitmapContext.cgContext.scaleBy(x: 1, y: -1)
background.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
label("CarPlay album layouts — all nine native presentations", x: 36, y: 30, width: 2472, size: 42)
label("Same 12 albums · 800 × 480 native captures · No layout selected", x: 36, y: 92, width: 2472, size: 26, color: secondary)
for (index, option) in options.enumerated() {
    try panel(option, x: CGFloat(36 + (index % 3) * 836), y: CGFloat(165 + (index / 3) * 635))
}
label("Density is specific to this display. Full-width rows need a separate plan for the complete library: native lists have an item limit.",
      x: 36, y: 2070, width: 2472, size: 24, color: secondary)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!
    .write(to: directory.appendingPathComponent("comparison.png"))

var page = CGRect(x: 0, y: 0, width: 872, height: 740)
let pdf = CGContext(directory.appendingPathComponent("carplay-options.pdf") as CFURL,
                    mediaBox: &page, nil)!
for option in options {
    pdf.beginPDFPage(nil)
    pdf.saveGState()
    pdf.translateBy(x: 0, y: page.height)
    pdf.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: true)
    background.setFill()
    NSRect(origin: .zero, size: page.size).fill()
    label("CarPlay album layouts · native comparison · no selection", x: 36, y: 24, width: 800, size: 19, color: secondary)
    try panel(option, x: 36, y: 75)
    label("Same 12 albums · 800 × 480 display · iOS 26 Simulator", x: 36, y: 694, width: 800, size: 18, color: secondary)
    NSGraphicsContext.restoreGraphicsState()
    pdf.restoreGState()
    pdf.endPDFPage()
}
pdf.closePDF()
print("Created comparison.png and carplay-options.pdf from \(options.count) captures")
