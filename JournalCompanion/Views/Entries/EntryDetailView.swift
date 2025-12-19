//
//  EntryDetailView.swift
//  JournalCompanion
//
//  Detail view for displaying entry information (read-only)
//

import SwiftUI

struct EntryDetailView: View {
    let entry: Entry
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @Environment(\.dismiss) var dismiss
    @State private var showEditView = false
    @State private var currentEntry: Entry
    @State private var showPlaybackView = false
    @State private var selectedAudioIndex: Int?

    init(entry: Entry) {
        self.entry = entry
        _currentEntry = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            List {
                // Audio Section (if audio entry)
                if hasAudio {
                    Section("Audio Recording") {
                        ForEach(Array((currentEntry.audioAttachments ?? []).enumerated()), id: \.offset) { index, filename in
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.red)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Recording \(index + 1)")
                                        .font(.subheadline)
                                    if let device = currentEntry.recordingDevice {
                                        Text(device)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    selectedAudioIndex = index
                                    showPlaybackView = true
                                } label: {
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let rate = currentEntry.sampleRate, let depth = currentEntry.bitDepth {
                            Text("\(rate)Hz • \(depth)-bit")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else if let rate = currentEntry.sampleRate {
                            Text("\(rate)Hz")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Entry Content Section (read-only with rendered markdown + wiki-links, audio embeds removed)
                Section("Entry") {
                    MarkdownWikiText(
                        text: contentWithoutAudioEmbeds,
                        places: vaultManager.places,
                        people: vaultManager.people,
                        lineLimit: nil,
                        font: .body
                    )
                }

                // Location Section (place wiki-links in content are also tappable)
                if let placeName = currentEntry.place {
                    Section("Location") {
                        if let place = vaultManager.places.first(where: { $0.name == placeName }) {
                            Text(place.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(placeName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // People Section removed - people now rendered inline as wiki-links in entry content

                // Details Section
                Section("Details") {
                    LabeledContent("Date") {
                        Text(currentEntry.dateCreated, style: .date)
                    }
                    LabeledContent("Time") {
                        Text(currentEntry.dateCreated, style: .time)
                    }

                    if !currentEntry.tags.isEmpty {
                        LabeledContent("Tags") {
                            Text(currentEntry.tags.joined(separator: ", "))
                                .font(.caption)
                        }
                    }
                }

                // Weather Section (if exists)
                if currentEntry.temperature != nil || currentEntry.condition != nil {
                    Section("Weather") {
                        if let temp = currentEntry.temperature {
                            LabeledContent("Temperature", value: "\(temp)°F")
                        }
                        if let condition = currentEntry.condition {
                            LabeledContent("Condition", value: condition)
                        }
                        if let humidity = currentEntry.humidity {
                            LabeledContent("Humidity", value: "\(humidity)%")
                        }
                        if let aqi = currentEntry.aqi {
                            LabeledContent("AQI", value: "\(aqi)")
                        }
                    }
                }
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showEditView = true
                    }
                }
            }
            .sheet(isPresented: $showEditView) {
                EntryEditView(viewModel: EntryEditViewModel(
                    entry: currentEntry,
                    vaultManager: vaultManager,
                    locationService: locationService
                ))
            }
            .onChange(of: showEditView) { _, isShowing in
                if !isShowing {
                    // Reload entry when edit view closes
                    Task {
                        await reloadEntry()
                    }
                }
            }
            .sheet(isPresented: $showPlaybackView) {
                if let index = selectedAudioIndex,
                   let filename = currentEntry.audioAttachments?[safe: index],
                   let vaultURL = vaultManager.vaultURL {

                    let audioURL = vaultURL
                        .appendingPathComponent("_attachments")
                        .appendingPathComponent("audio")
                        .appendingPathComponent(filename)

                    // Get transcription from content (extract the segment after the audio embed)
                    let transcription = extractTranscription(for: index)

                    // Load time ranges from SRT sidecar file
                    AudioPlaybackContainerView(
                        audioURL: audioURL,
                        filename: filename,
                        transcription: transcription,
                        entry: currentEntry,
                        vaultURL: vaultURL
                    )
                }
            }
        }
    }

    private func reloadEntry() async {
        guard let vaultURL = vaultManager.vaultURL else { return }

        do {
            let reader = EntryReader(vaultURL: vaultURL)
            let allEntries = try await reader.loadEntries(limit: 100)

            // Find the updated entry by ID
            if let updatedEntry = allEntries.first(where: { $0.id == currentEntry.id }) {
                currentEntry = updatedEntry
            }
        } catch {
            print("❌ Failed to reload entry: \(error)")
        }
    }

    // MARK: - Audio Playback

    private var hasAudio: Bool {
        currentEntry.audioAttachments != nil && !(currentEntry.audioAttachments?.isEmpty ?? true)
    }

    private var contentWithoutAudioEmbeds: String {
        var cleaned = currentEntry.content

        // Remove Obsidian audio embeds: ![[audio/filename.ext]]
        let audioEmbedPattern = #"!\[\[audio/[^\]]+\]\]"#
        if let regex = try? NSRegularExpression(pattern: audioEmbedPattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract transcription text for a specific audio segment
    private func extractTranscription(for index: Int) -> String {
        // The transcription follows the audio embed in the content
        // Pattern: ![[audio/filename.ext]]\n\nTranscription text\n\n
        let components = currentEntry.content.components(separatedBy: "![[audio/")

        guard index + 1 < components.count else { return "" }

        // Get the section after the target audio embed
        let section = components[index + 1]

        // Extract text between the embed close and next embed or end
        if let closeIndex = section.firstIndex(of: "]"),
           let doubleNewline = section[closeIndex...].range(of: "\n\n") {
            let startIndex = doubleNewline.upperBound
            let remainingText = section[startIndex...]

            // Find next audio embed or end of text
            if let nextEmbed = remainingText.range(of: "![[audio/") {
                return String(remainingText[..<nextEmbed.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return String(remainingText).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ""
    }
}

// MARK: - Audio Playback Container

/// Container view that loads time ranges from SRT sidecar file before presenting playback
struct AudioPlaybackContainerView: View {
    let audioURL: URL
    let filename: String
    let transcription: String
    let entry: Entry
    let vaultURL: URL

    @State private var timeRanges: [TimeRange] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading audio...")
            } else {
                AudioPlaybackView(
                    audioURL: audioURL,
                    transcription: transcription,
                    timeRanges: timeRanges
                )
            }
        }
        .task {
            await loadTimeRanges()
        }
    }

    private func loadTimeRanges() async {
        let audioFileManager = AudioFileManager(vaultURL: vaultURL)

        do {
            timeRanges = try await audioFileManager.loadTimeRanges(
                for: filename,
                entry: entry
            )
            print("📖 Loaded \(timeRanges.count) time ranges from SRT file")
        } catch {
            print("⚠️ Failed to load time ranges: \(error)")
            timeRanges = []
        }

        isLoading = false
    }
}

// MARK: - Array Safe Subscript Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
