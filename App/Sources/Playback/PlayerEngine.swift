import AVFoundation
import Combine
import MediaPlayer
import SongrKit
import UIKit

/// AVQueuePlayer-backed engine. The queue *rules* live in SongrKit's
/// PlaybackQueue (unit-tested); this class mirrors that model into actual
/// AVPlayerItems, the audio session, MPNowPlayingInfoCenter, and the remote
/// (lock screen / CarPlay) commands.
@MainActor
final class PlayerEngine: ObservableObject {
    @Published private(set) var queue: PlaybackQueue?
    @Published private(set) var album: Album?
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsed: TimeInterval = 0

    var currentTrack: Track? { queue?.current }

    private let player = AVQueuePlayer()
    private var source: LibrarySource?
    /// AVPlayerItem → index into `queue.tracks`, for advance detection.
    private var itemIndex: [ObjectIdentifier: Int] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var timeObserver: Any?
    private var artworkTask: Task<Void, Never>?

    init() {
        configureRemoteCommands()
        observePlayer()
    }

    // MARK: Public controls

    func play(album: Album, tracks: [Track], startIndex: Int, source: LibrarySource) {
        guard let newQueue = PlaybackQueue(tracks: tracks, startIndex: startIndex) else { return }
        self.source = source
        self.album = album
        queue = newQueue
        rebuildPlayerItems(from: newQueue)
        activateAudioSession()
        player.play()
    }

    func togglePlayPause() {
        if player.timeControlStatus == .paused {
            player.play()
        } else {
            player.pause()
        }
    }

    func skipToNext() {
        guard queue?.hasNext == true else { return }
        player.advanceToNextItem()
    }

    /// Songr behavior: restart the track unless we're near its start and an
    /// earlier album track exists.
    func skipToPrevious() {
        guard var queue else { return }
        if elapsed > 3 || !queue.hasPrevious {
            player.seek(to: .zero)
            return
        }
        queue.goToPrevious()
        self.queue = queue
        rebuildPlayerItems(from: queue)
        player.play()
    }

    func seek(to seconds: TimeInterval) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    var currentDuration: TimeInterval? {
        (queue?.current.durationMs).map { TimeInterval($0) / 1000 }
    }

    // MARK: Queue → AVPlayerItems

    private func rebuildPlayerItems(from queue: PlaybackQueue) {
        player.removeAllItems()
        itemIndex.removeAll()
        guard let source else { return }
        let offset = queue.currentIndex
        for (sliceIndex, track) in queue.playbackSlice.enumerated() {
            guard let request = try? source.streamRequest(for: track) else { continue }
            let asset = AVURLAsset(url: request.url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": request.headers
            ])
            let item = AVPlayerItem(asset: asset)
            itemIndex[ObjectIdentifier(item)] = offset + sliceIndex
            player.insert(item, after: nil)
        }
    }

    // MARK: Player observation

    private func observePlayer() {
        player.publisher(for: \.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] item in
                self?.currentItemChanged(item)
            }
            .store(in: &cancellables)

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status != .paused
                self?.pushNowPlayingInfo()
            }
            .store(in: &cancellables)

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.elapsed = max(time.seconds, 0)
                self?.pushNowPlayingElapsed()
            }
        }
    }

    private func currentItemChanged(_ item: AVPlayerItem?) {
        guard var queue else { return }
        if let item, let index = itemIndex[ObjectIdentifier(item)] {
            queue.jump(to: index)
            self.queue = queue
        } else if item == nil {
            // Album finished.
            isPlaying = false
        }
        elapsed = 0
        pushNowPlayingInfo()
    }

    // MARK: Audio session

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("audio session activation failed: \(error)")
        }
    }

    // MARK: Remote commands (lock screen + CarPlay)

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?
                .positionTime else { return .commandFailed }
            Task { @MainActor in self?.seek(to: position) }
            return .success
        }
    }

    // MARK: Now playing info

    private func pushNowPlayingInfo() {
        guard let track = queue?.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName ?? album?.artistName ?? "",
            MPMediaItemPropertyAlbumTitle: album?.title ?? "",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
        ]
        if let duration = currentDuration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        attachArtwork(for: track)
    }

    private func pushNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func attachArtwork(for track: Track) {
        artworkTask?.cancel()
        let path = track.thumbPath ?? album?.thumbPath
        artworkTask = Task { [weak self] in
            guard let image = await AppModel.shared.artwork(path: path, pixels: 600),
                  !Task.isCancelled else { return }
            guard self?.queue?.current.id == track.id else { return }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: image.size
            ) { _ in image }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}
