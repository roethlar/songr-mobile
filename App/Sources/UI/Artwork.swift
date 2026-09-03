import SongrKit
import SwiftUI

/// Async artwork in songr's visual image: `.tile .art` surface with the
/// `.mono-tile` monogram placeholder (initial letter, dim) until the server
/// transcode arrives. Sized by its frame; fetched once per path via
/// AppModel's cache.
struct RemoteArtwork: View {
    @EnvironmentObject private var model: AppModel
    let path: String?
    /// Monogram fallback (first character shown while/if no artwork).
    var monogram: String = "♪"
    var cornerRadius: CGFloat = SongrTheme.artRadius

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(SongrTheme.surface11)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                } else {
                    Text(monogramLetter)
                        .font(SongrTheme.font(max(geometry.size.width * 0.24, 13),
                                              .demiBold))
                        .foregroundStyle(SongrTheme.text42)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(SongrTheme.lineSubtle, lineWidth: 1)
            )
            .task(id: path) {
                guard let path else { return }
                let pixels = Int(max(geometry.size.width, 80) * 2)
                image = await model.artwork(path: path, pixels: pixels)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var monogramLetter: String {
        let first = monogram.trimmingCharacters(in: .whitespaces).first
        return first.map { String($0).uppercased() } ?? "♪"
    }
}
