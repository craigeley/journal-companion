//
//  AudioRecordingSheet.swift
//  JournalCompanion
//
//  Full-screen audio recording interface with real-time transcription
//

import SwiftUI

struct AudioRecordingSheet: View {
    @StateObject private var viewModel: AudioRecorderViewModel
    @Environment(\.dismiss) private var dismiss

    let vaultURL: URL
    let audioFormat: AudioFormat
    let onComplete: (URL, TimeInterval, String) -> Void

    init(
        vaultURL: URL,
        audioFormat: AudioFormat = .aac,
        onComplete: @escaping (URL, TimeInterval, String) -> Void
    ) {
        self.vaultURL = vaultURL
        self.audioFormat = audioFormat
        self.onComplete = onComplete
        self._viewModel = StateObject(wrappedValue: AudioRecorderViewModel(
            vaultURL: vaultURL,
            audioFormat: audioFormat
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Duration
                Text(viewModel.formattedDuration)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)

                // Waveform
                AudioWaveformView(
                    isRecording: viewModel.isRecording,
                    isPaused: viewModel.isPaused
                )
                .padding(.horizontal)

                // Transcription info
                VStack {
                    if viewModel.isTranscriptionAvailable {
                        Text("Audio will be transcribed after recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Transcription unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 60)
                .padding(.horizontal)

                Spacer()

                // Controls
                HStack(spacing: 40) {
                    // Cancel
                    Button {
                        Task {
                            await viewModel.cancelRecording()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }

                    // Pause/Resume
                    if viewModel.isRecording {
                        Button {
                            Task {
                                if viewModel.isPaused {
                                    await viewModel.resumeRecording()
                                } else {
                                    await viewModel.pauseRecording()
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                                .font(.title2)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                    }

                    // Stop
                    Button {
                        Task {
                            if let result = await viewModel.stopRecording() {
                                onComplete(result.url, result.duration, result.transcription)
                                dismiss()
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 70, height: 70)
                            .background(viewModel.isRecording ? Color.red : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!viewModel.isRecording)
                }
                .padding(.bottom, 40)
            }
            .padding()
            .navigationTitle("Record Audio")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .alert("Permission Required", isPresented: $viewModel.permissionsDenied) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Microphone and speech recognition permissions are required.")
            }
            .task {
                await viewModel.startRecording()
            }
        }
    }
}

#Preview {
    AudioRecordingSheet(
        vaultURL: URL(fileURLWithPath: "/tmp"),
        audioFormat: .aac
    ) { url, duration, transcription in
        print("Recording complete: \(duration)s")
        print("Transcription: \(transcription)")
    }
}
