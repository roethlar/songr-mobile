import Foundation

/// Pure queue model: an album played from a tapped track. The AVQueuePlayer
/// engine in the app mirrors this; keeping the rules here makes skip/advance
/// behavior unit-testable without AVFoundation.
public struct PlaybackQueue: Hashable, Sendable {
    /// Full album tracklist, in album order.
    public let tracks: [Track]
    /// Index into `tracks` of the item now playing.
    public private(set) var currentIndex: Int

    /// Starts the album at `startIndex` (clamped into range).
    public init?(tracks: [Track], startIndex: Int) {
        guard !tracks.isEmpty else { return nil }
        self.tracks = tracks
        self.currentIndex = min(max(startIndex, 0), tracks.count - 1)
    }

    public var current: Track { tracks[currentIndex] }

    /// Tracks from the current one to the album's end — what the player
    /// enqueues (playing from track N plays N, N+1, … end; earlier tracks
    /// are reachable via `goToPrevious`).
    public var playbackSlice: [Track] {
        Array(tracks[currentIndex...])
    }

    public var upcoming: [Track] {
        Array(tracks[(currentIndex + 1)...])
    }

    public var hasNext: Bool { currentIndex + 1 < tracks.count }
    public var hasPrevious: Bool { currentIndex > 0 }

    /// Move to the next track; false at the end of the album (playback stops).
    @discardableResult
    public mutating func advance() -> Bool {
        guard hasNext else { return false }
        currentIndex += 1
        return true
    }

    /// Move to the previous track; false at the first track (engines restart
    /// the current track instead).
    @discardableResult
    public mutating func goToPrevious() -> Bool {
        guard hasPrevious else { return false }
        currentIndex -= 1
        return true
    }

    /// Jump within the same queue (e.g. user taps another row).
    public mutating func jump(to index: Int) {
        currentIndex = min(max(index, 0), tracks.count - 1)
    }
}
