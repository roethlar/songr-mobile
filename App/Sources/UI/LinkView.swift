import SwiftUI

/// First-run Plex link on the songr surface. Two paths, both live until one
/// produces a token: in-app Safari sheet on the hosted sign-in page (strong
/// pin), or a short code entered at plex.tv/link from any external browser
/// (weak pin). Scrolls, so nothing clips in landscape.
struct LinkView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSignIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                SongrWordmark(size: 22)
                Text("Your music, straight from your Plex server.")
                    .font(SongrTheme.font(15))
                    .foregroundStyle(SongrTheme.soft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                switch model.phase {
                case .linking(let url, let code):
                    linking(url: url, code: code)
                default:
                    SongrAccentButton(label: "Sign in with Plex") {
                        model.beginLink()
                    }
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 40)
                }
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(SongrTheme.appBg)
    }

    @ViewBuilder
    private func linking(url: URL, code: String) -> some View {
        VStack(spacing: 20) {
            SongrAccentButton(label: "Sign in with Plex") {
                showSignIn = true
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 40)

            VStack(spacing: 6) {
                Text("Or, in any browser, go to")
                    .foregroundStyle(SongrTheme.soft)
                Link("plex.tv/link", destination: URL(string: "https://plex.tv/link")!)
                    .foregroundStyle(SongrTheme.accentBright)
                Text("and enter this code:")
                    .foregroundStyle(SongrTheme.soft)
                Text(code)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .kerning(3)
                    .foregroundStyle(SongrTheme.accentBright)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(SongrTheme.inset)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(SongrTheme.line, lineWidth: 1)
                    )
            }
            .font(SongrTheme.font(14))

            HStack(spacing: 8) {
                ProgressView().tint(SongrTheme.accent)
                Text("Waiting for Plex sign-in…")
                    .font(SongrTheme.font(13))
                    .foregroundStyle(SongrTheme.soft)
            }
            SongrBarButton(label: "Cancel") { model.cancelLink() }
        }
        .sheet(isPresented: $showSignIn) {
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}
