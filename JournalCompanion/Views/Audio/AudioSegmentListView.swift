//
//  AudioSegmentListView.swift
//  JournalCompanion
//
//  Displays list of recorded audio segments
//

import SwiftUI

struct AudioSegmentListView: View {
    @ObservedObject var segmentManager: AudioSegmentManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Audio Recordings")
                    .font(.headline)
                Spacer()
                Text(segmentManager.formattedTotalDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(Array(segmentManager.segments.enumerated()), id: \.element.id) { index, segment in
                HStack(spacing: 12) {
                    // Segment number
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.red)
                        .clipShape(Circle())

                    // Transcription preview
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.transcriptionPreview)
                            .font(.subheadline)
                            .lineLimit(2)

                        Text(segment.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()

                    // Delete button
                    Button {
                        withAnimation {
                            segmentManager.removeSegment(segment)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    @Previewable @StateObject var manager = AudioSegmentManager()

    VStack {
        AudioSegmentListView(segmentManager: manager)
            .padding()
    }
    .onAppear {
        // Add some preview data
        manager.addSegment(
            tempURL: URL(fileURLWithPath: "/tmp/test1.m4a"),
            duration: 45.2,
            transcription: "This is a test transcription of the first audio segment.",
            timeRanges: [],
            format: .aac
        )
        manager.addSegment(
            tempURL: URL(fileURLWithPath: "/tmp/test2.m4a"),
            duration: 30.8,
            transcription: "Second segment with different content.",
            timeRanges: [],
            format: .aac
        )
    }
}
