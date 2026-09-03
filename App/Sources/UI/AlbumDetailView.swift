import SongrKit
import SwiftUI

/// Album page in the image of the web's `.panel`: cover + facts (`.pt`,
/// `.pa`), a Play action (`.pb`), then the track list (`.tr` rows: dim
/// number, title, duration; the playing track goes gold). Tapping a track
/// plays the album from that track (Browse UX directive).
/// Portrait stacks cover over tracks; landscape puts the cover column left
/// and the track list right, exactly like the web's `.pleft`/`.pright`.
struct AlbumDetailView: View {
    @EnvironmentObject private var model: AppModel
    let album: Album

    @State private var tracks: [Track] = []
    @State private var loadFailed = false

    var body: some View {
        VStack(spacing: 0) {
            SongrContextRow(title: album.title,
                            fact: album.year.map(String.init))
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    landscape
                } else {
                    portrait
                }
            }
        }
        .background(SongrTheme.bg)
        .task {
            guard tracks.isEmpty else { return }
            do {
                tracks = try await model.tracks(for: album)
            } catch {
                loadFailed = true
            }
        }
    }

    private var portrait: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    RemoteArtwork(path: album.thumbPath, monogram: album.title)
                        .frame(width: 148, height: 148)
                    facts
                    Spacer(minLength: 0)
                }
                playButton
                trackList
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var landscape: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                RemoteArtwork(path: album.thumbPath, monogram: album.title)
                    .frame(width: 172, height: 172)
                facts
                playButton
                    .frame(width: 172)
                Spacer(minLength: 0)
            }
            ScrollView {
                trackList
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    /// `.pt` title + `.pa` artist + year fact.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(album.title)
                .font(SongrTheme.font(20, .demiBold))
                .foregroundStyle(SongrTheme.textHigh)
                .lineLimit(3)
            Text(album.artistName)
                .font(SongrTheme.font(14))
                .foregroundStyle(SongrTheme.soft)
                .lineLimit(2)
            if let year = album.year {
                Text(String(year))
                    .font(SongrTheme.font(12))
                    .foregroundStyle(SongrTheme.dim)
            }
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if !tracks.isEmpty {
            SongrPanelButton(label: "Play Album") {
                model.play(album: album, tracks: tracks, startAt: 0)
            }
        }
    }

    @ViewBuilder
    private var trackList: some View {
        if loadFailed {
            Text("Couldn't load tracks")
                .font(SongrTheme.font(13))
                .foregroundStyle(SongrTheme.error)
                .padding(.vertical, 12)
        } else if tracks.isEmpty {
            HStack {
                Spacer()
                ProgressView().tint(SongrTheme.accent)
                Spacer()
            }
            .padding(.vertical, 20)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track,
                             isCurrent: model.player.currentTrack?.id == track.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.play(album: album, tracks: tracks, startAt: index)
                        }
                }
            }
        }
    }
}

/// `.tr` — number (`.tn`, dim, right-aligned), title (`.tnm`), duration.
private struct TrackRow: View {
    let track: Track
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(SongrTheme.accent)
                    .frame(width: 24, alignment: .trailing)
            } else {
                Text("\(track.trackNumber)")
                    .font(SongrTheme.font(12).monospacedDigit())
                    .foregroundStyle(SongrTheme.dim)
                    .frame(width: 24, alignment: .trailing)
            }
            Text(track.title)
                .font(SongrTheme.font(15))
                .foregroundStyle(isCurrent ? SongrTheme.accentBright : SongrTheme.listText)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let ms = track.durationMs {
                Text(Self.timestamp(ms: ms))
                    .font(SongrTheme.font(12).monospacedDigit())
                    .foregroundStyle(SongrTheme.dim)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isCurrent ? SongrTheme.hoverSubtle : .clear)
        )
    }

    static func timestamp(ms: Int) -> String {
        let totalSeconds = ms / 1000
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
