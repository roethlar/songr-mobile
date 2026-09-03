import SongrKit
import SwiftUI

/// Songr-styled settings sheet: switch the music library (the same cards as
/// first-run), see the linked server, unlink. Backend-specific controls live
/// here — never crammed into the header bar.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var libraries: [MusicLibrary]?
    @State private var librariesFailed = false

    var body: some View {
        ZStack {
            SongrTheme.panel.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("SETTINGS")
                            .font(SongrTheme.font(12, .demiBold))
                            .tracking(2.5)
                            .foregroundStyle(SongrTheme.accent)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(SongrTheme.dim)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                    }

                    section(title: "Music Library") {
                        if let libraries {
                            if libraries.count > 1 {
                                Text("Pick which library songr browses.")
                                    .font(SongrTheme.font(13))
                                    .foregroundStyle(SongrTheme.soft)
                            }
                            ForEach(libraries) { library in
                                LibraryCard(library: library,
                                            isCurrent: library.id == model.currentSectionKey) {
                                    guard library.id != model.currentSectionKey else { return }
                                    model.selectLibrary(library)
                                    dismiss()
                                }
                            }
                        } else if librariesFailed {
                            Text("Couldn't reach the server to list libraries.")
                                .font(SongrTheme.font(13))
                                .foregroundStyle(SongrTheme.error)
                        } else {
                            ProgressView().tint(SongrTheme.accent)
                        }
                    }

                    section(title: "Plex Account") {
                        SongrPanelButton(label: "Unlink Plex Account",
                                         role: .destructive) {
                            model.unlink()
                            dismiss()
                        }
                        Text("Removes the saved token and library choice from this device.")
                            .font(SongrTheme.font(11.5))
                            .foregroundStyle(SongrTheme.dim)
                    }
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(SongrTheme.panel)
        .task {
            guard let source = model.source else {
                librariesFailed = true
                return
            }
            do {
                libraries = try await source.fetchMusicLibraries()
            } catch {
                librariesFailed = true
            }
        }
    }

    @ViewBuilder
    private func section(title: String,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(SongrTheme.font(11, .demiBold))
                .tracking(2)
                .foregroundStyle(SongrTheme.dim)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
