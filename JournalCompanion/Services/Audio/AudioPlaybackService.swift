//
//  AudioPlaybackService.swift
//  JournalCompanion
//
//  Basic audio playback service using AVAudioPlayer
//

import Foundation
import AVFoundation

// MARK: - Audio Playback Service

actor AudioPlaybackService {
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?

    // MARK: - Public Interface

    /// Start playing audio from URL
    func play(url: URL) async throws {
        // Stop any existing playback
        await stop()

        // Create and configure audio player
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()

        // Configure audio session for playback
        try await configureAudioSession()

        // Start playing
        audioPlayer?.play()
        print("▶️ Playing audio: \(url.lastPathComponent)")
    }

    /// Pause playback
    func pause() async {
        audioPlayer?.pause()
        print("⏸ Paused playback")
    }

    /// Resume playback
    func resume() async {
        audioPlayer?.play()
        print("▶️ Resumed playback")
    }

    /// Stop playback
    func stop() async {
        audioPlayer?.stop()
        audioPlayer = nil
        print("⏹ Stopped playback")
    }

    /// Seek to time
    func seek(to time: TimeInterval) async {
        audioPlayer?.currentTime = time
    }

    /// Get current playback time
    func currentTime() async -> TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    /// Get total duration
    func duration() async -> TimeInterval {
        audioPlayer?.duration ?? 0
    }

    /// Check if currently playing
    func isPlaying() async -> Bool {
        audioPlayer?.isPlaying ?? false
    }

    /// Set playback rate (0.5x - 2.0x)
    func setRate(_ rate: Float) async {
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
    }

    // MARK: - Private Helpers

    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
}
