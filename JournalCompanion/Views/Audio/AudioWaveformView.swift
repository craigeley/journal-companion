//
//  AudioWaveformView.swift
//  JournalCompanion
//
//  Animated waveform visualization for audio recording
//

import SwiftUI

struct AudioWaveformView: View {
    let isRecording: Bool
    let isPaused: Bool

    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 40)
    @State private var timer: Timer?

    private let barCount = 40
    private let barSpacing: CGFloat = 4
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.2), value: amplitudes[index])
            }
        }
        .frame(height: maxHeight)
        .onChange(of: isRecording) { _, recording in
            if recording && !isPaused {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                stopAnimation()
            } else if isRecording {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private var barColor: Color {
        if !isRecording {
            return .gray.opacity(0.3)
        } else if isPaused {
            return .orange.opacity(0.6)
        } else {
            return .red.opacity(0.8)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < amplitudes.count else { return minHeight }
        let amplitude = amplitudes[index]
        return minHeight + (maxHeight - minHeight) * amplitude
    }

    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateAmplitudes()
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil

        // Reset to baseline
        withAnimation {
            amplitudes = Array(repeating: 0.3, count: barCount)
        }
    }

    private func updateAmplitudes() {
        withAnimation {
            amplitudes = amplitudes.enumerated().map { index, _ in
                // Create wave pattern with some randomness
                let wave = sin(Double(index) * 0.3 + Date().timeIntervalSince1970 * 2)
                let normalized = (wave + 1) / 2 // 0...1
                let randomness = CGFloat.random(in: 0.7...1.3)
                return CGFloat(normalized) * randomness
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VStack {
            Text("Not Recording")
                .font(.caption)
            AudioWaveformView(isRecording: false, isPaused: false)
        }

        VStack {
            Text("Recording")
                .font(.caption)
            AudioWaveformView(isRecording: true, isPaused: false)
        }

        VStack {
            Text("Paused")
                .font(.caption)
            AudioWaveformView(isRecording: true, isPaused: true)
        }
    }
    .padding()
}
