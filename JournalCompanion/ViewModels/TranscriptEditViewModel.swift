//
//  TranscriptEditViewModel.swift
//  JournalCompanion
//
//  View model for editing audio transcript time ranges
//

import Foundation
import Combine

/// Editable wrapper for TimeRange (since TimeRange has immutable properties)
struct EditableTimeRange: Identifiable {
    let id: UUID = UUID()
    let start: TimeInterval
    let end: TimeInterval
    var text: String

    init(from timeRange: TimeRange) {
        self.start = timeRange.start
        self.end = timeRange.end
        self.text = timeRange.text
    }

    func toTimeRange() -> TimeRange {
        TimeRange(text: text, start: start, end: end)
    }
}

@MainActor
class TranscriptEditViewModel: ObservableObject {
    @Published var editableTimeRanges: [EditableTimeRange]
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
        self.editableTimeRanges = timeRanges.map { EditableTimeRange(from: $0) }
        self.vaultManager = vaultManager
    }

    /// Validate that no time range has empty text
    var isValid: Bool {
        !editableTimeRanges.contains { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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

            // Convert editable time ranges back to TimeRange
            let timeRanges = editableTimeRanges.map { $0.toTimeRange() }

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
