import SafariServices
import SwiftUI

/// In-app Safari for the hosted Plex sign-in page. Shares Safari's cookies,
/// so an owner already signed in to plex.tv just taps Accept.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
