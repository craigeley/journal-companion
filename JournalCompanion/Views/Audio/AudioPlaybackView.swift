//
//  AudioPlaybackView.swift
//  JournalCompanion
//
//  Audio playback with synchronized text highlighting
//

import SwiftUI

struct AudioPlaybackView: View {
    let audioURL: URL
    let transcription: String
    let timeRanges: [TimeRange]

    @State private var playbackService = AudioPlaybackService()
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var playbackRate: Float = 1.0

    // Timer for updating current time
    @State private var timer: Timer?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
                // Scrollable transcript with highlighting
                ScrollViewReader { proxy in
                    ScrollView {
                        if timeRanges.isEmpty {
                            // No time ranges - show plain text
                            Text(transcription)
                                .font(.body)
                                .padding()
                        } else {
                            // Show flowing text with word-level highlighting
                            FlowingTranscriptView(
                                timeRanges: timeRanges,
                                currentTime: currentTime
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .onAppear {
                                print("🎵 Loaded \(timeRanges.count) time ranges")
                                print("🎵 Transcription: '\(transcription.prefix(50))...'")
                                for (i, range) in timeRanges.prefix(3).enumerated() {
                                    print("🎵 Range \(i): '\(range.text)' (\(range.start)s - \(range.end)s)")
                                }
                            }
                        }
                    }
                    .onChange(of: currentTime) { _, _ in
                        // Auto-scroll to highlighted segment (removed - not needed for flowing text)
                    }
                }

                Spacer()

                // Playback controls
                VStack(spacing: 16) {
                    // Progress bar
                    VStack(spacing: 8) {
                        Slider(value: $currentTime, in: 0...max(duration, 0.1)) { editing in
                            if !editing {
                                Task {
                                    await playbackService.seek(to: currentTime)
                                }
                            }
                        }

                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption)
                                .monospacedDigit()
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }

                    // Play/Pause button
                    HStack(spacing: 40) {
                        // Playback rate
                        Menu {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                Button("\(String(format: "%.2f", rate))x") {
                                    playbackRate = Float(rate)
                                    Task {
                                        await playbackService.setRate(Float(rate))
                                    }
                                }
                            }
                        } label: {
                            Text("\(String(format: "%.2f", playbackRate))x")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60)
                        }

                        // Play/Pause
                        Button {
                            Task {
                                await togglePlayback()
                            }
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.red)
                                .clipShape(Circle())
                        }

                        Spacer()
                            .frame(width: 60)
                    }
                }
                .padding()
            }
        .navigationTitle("Audio Playback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    Task {
                        await playbackService.stop()
                    }
                    dismiss()
                }
            }
        }
        .task {
            await loadAudio()
        }
        .onDisappear {
            stopTimer()
            Task {
                await playbackService.stop()
            }
        }
    }

    // MARK: - Playback Logic

    private func loadAudio() async {
        do {
            try await playbackService.play(url: audioURL)
            duration = await playbackService.duration()
            await playbackService.pause() // Start paused
            isPlaying = false
        } catch {
            print("❌ Failed to load audio: \(error)")
        }
    }

    private func togglePlayback() async {
        if isPlaying {
            await playbackService.pause()
            stopTimer()
            isPlaying = false
        } else {
            await playbackService.resume()
            startTimer()
            isPlaying = true
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                currentTime = await playbackService.currentTime()

                // Stop when playback finishes
                if currentTime >= duration && isPlaying {
                    await playbackService.stop()
                    stopTimer()
                    isPlaying = false
                    currentTime = 0
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Highlighting Logic

    /// Check if a time range should be highlighted based on current playback time
    private func isHighlighted(_ range: TimeRange) -> Bool {
        currentTime >= range.start && currentTime < range.end
    }

    // MARK: - Formatting

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Flowing Transcript View

/// Displays transcription as natural flowing text with word-level highlighting
struct FlowingTranscriptView: View {
    let timeRanges: [TimeRange]
    let currentTime: TimeInterval

    var body: some View {
        Text(buildAttributedString())
            .font(.body)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()

        for range in timeRanges {
            var segment = AttributedString(range.text)

            // Apply yellow highlight to currently playing segment
            if currentTime >= range.start && currentTime < range.end {
                segment.backgroundColor = Color.yellow.opacity(0.4)
            }

            result += segment

            // Add space after word (unless it's punctuation-only)
            if !range.text.trimmingCharacters(in: .whitespaces).isEmpty {
                result += AttributedString(" ")
            }

            // Add line break after sentence-ending punctuation
            if endsWithSentence(range.text) {
                result += AttributedString("\n\n")
            }
        }

        return result
    }

    /// Check if text ends with sentence-ending punctuation
    private func endsWithSentence(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
    }
}

#Preview {
    AudioPlaybackView(
        audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
        transcription: "This is a test transcription",
        timeRanges: [
            TimeRange(text: "This", start: 0.0, end: 0.5),
            TimeRange(text: "is", start: 0.5, end: 0.8),
            TimeRange(text: "a", start: 0.8, end: 1.0),
            TimeRange(text: "test", start: 1.0, end: 1.5),
            TimeRange(text: "transcription", start: 1.5, end: 2.5)
        ]
    )
}
