import SongrKit
import SwiftUI

/// The web's `.player` bar, docked under the browse pane: app-bg surface,
/// hairline on top, `.npt`/`.nps` titles left, `.tp` transport right with
/// the ringed play button (`.tp .big`). Tap anywhere else opens the sheet.
struct PlayerBar: View {
    @EnvironmentObject private var model: AppModel
    let onTap: () -> Void

    var body: some View {
        if let track = model.player.currentTrack {
            HStack(spacing: 12) {
                RemoteArtwork(path: track.thumbPath ?? model.player.album?.thumbPath,
                              monogram: model.player.album?.title ?? track.title)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(SongrTheme.font(14, .demiBold))
                        .foregroundStyle(SongrTheme.text)
                        .lineLimit(1)
                    Text(track.artistName ?? model.player.album?.artistName ?? "")
                        .font(SongrTheme.font(11.5))
                        .foregroundStyle(SongrTheme.dim)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button {
                    model.player.togglePlayPause()
                } label: {
                    Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(SongrTheme.textMid)
                        .frame(width: 38, height: 38)
                        .overlay(Circle().strokeBorder(SongrTheme.line20, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button {
                    model.player.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(SongrTheme.textMid)
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)
                .disabled(model.player.queue?.hasNext != true)
                .opacity(model.player.queue?.hasNext == true ? 1 : 0.35)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(SongrTheme.appBg)
            .overlay(alignment: .top) {
                Rectangle().fill(SongrTheme.line).frame(height: 1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}

/// Full now-playing in the image of the web's NowPlayingOverlay `.np-dialog`:
/// panel surface, square art (8pt radius), `.np-title`/`.np-artist`, the 6px
/// gold progress bar with times under, and the round `.np-ctrl` transport —
/// 44pt raised rings around a 56pt gold play. Portrait stacks; landscape
/// splits art | meta like the dialog's two columns.
struct NowPlayingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrubTarget: Double?

    var body: some View {
        ZStack {
            SongrTheme.panel.ignoresSafeArea()
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    landscape
                } else {
                    portrait
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(SongrTheme.dim)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(SongrTheme.panel)
    }

    private var portrait: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)
            art
                .frame(maxWidth: 340)
            meta
            progress
                .padding(.horizontal, 4)
            controls
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
    }

    private var landscape: some View {
        HStack(spacing: 28) {
            art
                .frame(maxWidth: 300)
            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 0)
                meta
                progress
                controls
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    private var art: some View {
        RemoteArtwork(path: model.player.currentTrack?.thumbPath
                        ?? model.player.album?.thumbPath,
                      monogram: model.player.album?.title ?? "♪",
                      cornerRadius: 8)
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.55), radius: 22, y: 10)
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.player.currentTrack?.title ?? "Nothing playing")
                .font(SongrTheme.font(24, .demiBold))
                .foregroundStyle(SongrTheme.text)
                .lineLimit(2)
            Text(model.player.currentTrack?.artistName
                    ?? model.player.album?.artistName ?? "")
                .font(SongrTheme.font(17))
                .foregroundStyle(SongrTheme.soft)
                .lineLimit(1)
            Text(model.player.album?.title ?? "")
                .font(SongrTheme.font(15))
                .foregroundStyle(SongrTheme.soft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `.np-progress` — 6px track on the hover surface, gold fill, times under.
    private var progress: some View {
        let duration = max(model.player.currentDuration ?? 0, 0)
        let position = min(scrubTarget ?? model.player.elapsed, duration)
        let fraction = duration > 0 ? position / duration : 0
        return VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(SongrTheme.hover)
                    Capsule().fill(SongrTheme.accent)
                        .frame(width: max(geometry.size.width * fraction, 0))
                }
                .contentShape(Rectangle().inset(by: -12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                            scrubTarget = fraction * duration
                        }
                        .onEnded { _ in
                            if let target = scrubTarget {
                                model.player.seek(to: target)
                            }
                            scrubTarget = nil
                        }
                )
            }
            .frame(height: 6)
            HStack {
                Text(timestamp(position))
                Spacer()
                Text("-" + timestamp(max(duration - position, 0)))
            }
            .font(SongrTheme.font(12).monospacedDigit())
            .foregroundStyle(SongrTheme.soft)
        }
    }

    /// `.np-ctrl` ring buttons; `.np-ctrl.primary` gold play.
    private var controls: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)
            ringButton(icon: "backward.fill") {
                model.player.skipToPrevious()
            }
            Button {
                model.player.togglePlayPause()
            } label: {
                Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SongrTheme.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(SongrTheme.accent))
            }
            .buttonStyle(.plain)
            ringButton(icon: "forward.fill",
                       disabled: model.player.queue?.hasNext != true) {
                model.player.skipToNext()
            }
            Spacer(minLength: 0)
        }
    }

    private func ringButton(icon: String, disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(SongrTheme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(SongrTheme.raise))
                .overlay(Circle().strokeBorder(SongrTheme.line12, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded())
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
