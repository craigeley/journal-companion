//
//  AudioRecordButton.swift
//  JournalCompanion
//
//  Microphone button for audio recording
//

import SwiftUI

struct AudioRecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 20))
                .foregroundStyle(isRecording ? .red : .primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioRecordButton(isRecording: false) {
            print("Start recording")
        }

        AudioRecordButton(isRecording: true) {
            print("Stop recording")
        }
    }
}
