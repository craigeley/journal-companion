//
//  TranscriptEditViewModel.swift
//  JournalCompanion
//
//  View model for editing audio transcript time ranges
//

import Foundation
import Combine

@MainActor
class TranscriptEditViewModel: ObservableObject {
    @Published var timeRanges: [TimeRange]
    @Published var isSaving: Bool = false
    @Published var saveError: String?

    let entry: Entry
    let audioFilename: String
    let vaultManager: VaultManager

    init(
        entry: Entry,
        audioFilename: String,
        timeRanges: [TimeRange],
        vaultManager: VaultManager
    ) {
        self.entry = entry
        self.audioFilename = audioFilename
        self.timeRanges = timeRanges
        self.vaultManager = vaultManager
    }

    /// Validate that no time range has empty text
    var isValid: Bool {
        !timeRanges.contains { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Save updated transcript to SRT file and re-mirror to entry content
    func save() async -> Bool {
        guard isValid else {
            saveError = "Transcript segments cannot be empty"
            return false
        }

        guard let vaultURL = vaultManager.vaultURL else {
            saveError = "No vault configured"
            return false
        }

        isSaving = true
        saveError = nil

        do {
            let audioFileManager = AudioFileManager(vaultURL: vaultURL)
            let entryWriter = EntryWriter(vaultURL: vaultURL)

            // Update SRT file with edited time ranges
            try await audioFileManager.updateSRTFile(
                for: audioFilename,
                entry: entry,
                newTimeRanges: timeRanges
            )

            // Re-mirror SRT to entry content
            var updatedEntry = entry
            try await entryWriter.mirrorTranscriptsToContent(
                entry: &updatedEntry,
                audioFileManager: audioFileManager
            )

            // Save updated entry
            try await entryWriter.update(entry: updatedEntry)

            // Reload entries in vault manager
            _ = try await vaultManager.loadEntries(limit: 100)

            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Format time interval as MM:SS
    func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Format time range for display
    func formatTimeRange(_ start: TimeInterval, _ end: TimeInterval) -> String {
        "\(formatTime(start)) - \(formatTime(end))"
    }
}
