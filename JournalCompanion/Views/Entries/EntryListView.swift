//
//  EntryListView.swift
//  JournalCompanion
//
//  Browse and search journal entries
//

import SwiftUI

struct EntryListView: View {
    @StateObject var viewModel: EntryListViewModel

    @State private var selectedEntry: Entry?
    @State private var showDetailView = false
    @State private var entryToDelete: Entry?
    @State private var showDeleteConfirmation = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading entries...")
                } else if viewModel.filteredEntries.isEmpty && viewModel.searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Entries", systemImage: "doc.text")
                    } description: {
                        Text("Create your first entry using the + button")
                    }
                } else if viewModel.filteredEntries.isEmpty {
                    ContentUnavailableView.search
                } else {
                    entriesList
                }
            }
            .navigationTitle("Entries")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .task {
                if viewModel.entries.isEmpty {
                    await viewModel.loadEntries()
                }
            }
            .refreshable {
                await viewModel.loadEntries()
            }
            .sheet(isPresented: $showDetailView) {
                if let entry = selectedEntry {
                    EntryDetailView(entry: entry)
                        .environmentObject(viewModel.vaultManager)
                }
            }
            .onChange(of: showDetailView) { _, isShowing in
                if !isShowing {
                    // Refresh entries when edit view closes
                    Task {
                        await viewModel.loadEntries()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewModel.vaultManager)
            }
            .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        Task {
                            do {
                                try await viewModel.deleteEntry(entry)
                            } catch {
                                print("❌ Failed to delete entry: \(error)")
                            }
                        }
                    }
                }
            } message: {
                Text("This will permanently delete the entry and cannot be undone.")
            }
        }
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.entriesByDate(), id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        EntryRowView(entry: entry, placeCallout: viewModel.callout(for: entry.place), places: viewModel.places, people: viewModel.people)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                                showDetailView = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    entryToDelete = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(section.date, style: .date)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Entry Row
struct EntryRowView: View {
    let entry: Entry
    let placeCallout: String?
    let places: [Place]
    let people: [Person]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with time, place, and audio indicator
            HStack {
                Text(entry.dateCreated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Audio indicator for audio entries
                if isAudioEntry {
                    Image(systemName: "waveform")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .imageScale(.small)
                }

                if let place = entry.place {
                    Image(systemName: PlaceIcon.systemName(for: placeCallout ?? ""))
                        .foregroundStyle(PlaceIcon.color(for: placeCallout ?? ""))
                        .font(.caption)
                        .imageScale(.small)
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Weather indicator
                if let temp = entry.temperature, let condition = entry.condition {
                    HStack(spacing: 4) {
                        Text(weatherEmoji(for: condition))
                            .font(.caption)
                        Text("\(temp)°")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Content preview (with markdown + wiki-links, audio embeds removed)
            MarkdownWikiText(
                text: contentWithoutAudioEmbeds,
                places: places,
                people: people,
                lineLimit: 3,
                font: .body
            )

            // Tags
            if !entry.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(entry.tags.filter { $0 != "entry" && $0 != "iPhone" }, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    /// Check if this is an audio entry
    private var isAudioEntry: Bool {
        entry.audioAttachments != nil && !(entry.audioAttachments?.isEmpty ?? true)
    }

    /// Content with audio embeds removed for cleaner display
    private var contentWithoutAudioEmbeds: String {
        var cleaned = entry.content

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

        // Clean up extra whitespace left behind
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func weatherEmoji(for condition: String) -> String {
        switch condition.lowercased() {
        case let c where c.contains("clear"): return "☀️"
        case let c where c.contains("cloud"): return "☁️"
        case let c where c.contains("rain"): return "🌧️"
        case let c where c.contains("snow"): return "❄️"
        case let c where c.contains("storm"): return "⛈️"
        case let c where c.contains("fog"): return "🌫️"
        case let c where c.contains("wind"): return "💨"
        default: return "🌤️"
        }
    }

}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let viewModel = EntryListViewModel(vaultManager: vaultManager, locationService: locationService)
    return EntryListView(viewModel: viewModel)
}
