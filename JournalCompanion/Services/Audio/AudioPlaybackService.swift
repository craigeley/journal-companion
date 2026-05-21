//
//  AudioPlaybackService.swift
//  JournalCompanion
//
//  Audio playback service using AVPlayer (supports both local files and HTTPS streaming)
//

import Foundation
import AVFoundation

// MARK: - Audio Playback Service

actor AudioPlaybackService {
    private var player: AVPlayer?
    private var currentRate: Float = 1.0
    private var cachedDuration: TimeInterval = 0

    // MARK: - Public Interface

    /// Start playing audio from URL (local file or remote HTTPS)
    func play(url: URL) async throws {
        // Stop any existing playback
        await stop()

        // Configure audio session for playback
        try await configureAudioSession()

        // Build player item and resolve duration before kicking off playback so the
        // UI can render an accurate scrubber even for streamed audio.
        let asset = AVURLAsset(url: url)
        cachedDuration = (try? await asset.load(.duration).seconds) ?? 0

        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.allowsExternalPlayback = true
        newPlayer.automaticallyWaitsToMinimizeStalling = true

        player = newPlayer
        newPlayer.play()
        if currentRate != 1.0 {
            newPlayer.rate = currentRate
        }
        print("▶️ Playing audio: \(url.lastPathComponent)")
    }

    /// Pause playback
    func pause() async {
        player?.pause()
        print("⏸ Paused playback")
    }

    /// Resume playback
    func resume() async {
        guard let player else { return }
        player.play()
        if currentRate != 1.0 {
            player.rate = currentRate
        }
        print("▶️ Resumed playback")
    }

    /// Stop playback
    func stop() async {
        player?.pause()
        player = nil
        cachedDuration = 0
        print("⏹ Stopped playback")
    }

    /// Seek to time
    func seek(to time: TimeInterval) async {
        guard let player else { return }
        let target = CMTime(seconds: time, preferredTimescale: 1000)
        await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Get current playback time
    func currentTime() async -> TimeInterval {
        guard let player else { return 0 }
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    /// Get total duration
    func duration() async -> TimeInterval {
        // Prefer the duration we resolved during play(), since the player item's
        // duration may still be reported as indefinite for fresh remote items.
        if cachedDuration > 0 {
            return cachedDuration
        }
        guard let seconds = player?.currentItem?.duration.seconds, seconds.isFinite else {
            return 0
        }
        return seconds
    }

    /// Check if currently playing
    func isPlaying() async -> Bool {
        player?.timeControlStatus == .playing
    }

    /// Set playback rate (0.5x - 2.0x)
    func setRate(_ rate: Float) async {
        currentRate = rate
        // Setting rate on a paused player starts playback, so only apply it when
        // the player is already running.
        if player?.timeControlStatus == .playing {
            player?.rate = rate
        }
    }

    // MARK: - Private Helpers

    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
}
