import SongrKit
import SwiftUI

/// The server has more than one music library (Plex models music, podcasts,
/// and audiobooks all as `artist` sections) — the user picks; songr never
/// guesses. Shown during first-run/link, and again from Settings. Cards use
/// the web's `.gcard` look: inset surface, hairline, gold when chosen.
struct LibraryPickerView: View {
    @EnvironmentObject private var model: AppModel
    let libraries: [MusicLibrary]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 30)
                SongrWordmark(size: 15)
                VStack(spacing: 8) {
                    Text("Choose your music library")
                        .font(SongrTheme.font(21, .demiBold))
                        .foregroundStyle(SongrTheme.textHigh)
                    Text("This Plex server has \(libraries.count) music-type libraries. Songr will browse the one you pick — you can change it later in Settings.")
                        .font(SongrTheme.font(14))
                        .foregroundStyle(SongrTheme.soft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 9) {
                    ForEach(libraries) { library in
                        LibraryCard(library: library,
                                    isCurrent: library.id == model.currentSectionKey) {
                            model.selectLibrary(library)
                        }
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)

                if model.snapshot != nil {
                    SongrBarButton(label: "Cancel") {
                        model.cancelLibraryChoice()
                    }
                }
                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity)
        }
        .background(SongrTheme.appBg)
    }
}

/// `.gcard` — name (`.gn`), letterspaced fact line (`.gc`).
struct LibraryCard: View {
    let library: MusicLibrary
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(library.title)
                        .font(SongrTheme.font(16, .demiBold))
                        .foregroundStyle(SongrTheme.textHigh)
                    Text("Plex library \(library.id)")
                        .font(SongrTheme.font(11))
                        .tracking(1)
                        .foregroundStyle(SongrTheme.dim)
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Text("CURRENT")
                        .font(SongrTheme.font(10, .bold))
                        .tracking(1.2)
                        .foregroundStyle(SongrTheme.accentBright)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(SongrTheme.accent.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(SongrTheme.inset))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCurrent ? SongrTheme.accent : SongrTheme.line,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
