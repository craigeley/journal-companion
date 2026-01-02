//
//  EntryListView.swift
//  JournalCompanion
//
//  Browse and search journal entries
//

import SwiftUI

struct EntryListView: View {
    @StateObject var viewModel: EntryListViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedEntry: Entry?
    @State private var entryToDelete: Entry?
    @State private var showDeleteConfirmation = false
    @State private var showAttachmentDeleteConfirmation = false
    @State private var showSettings = false
    @State private var showFilterSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Filter chips (if active)
                if viewModel.hasActiveFilters {
                    EntryFilterChipsView(
                        chips: viewModel.activeFilterChips,
                        onClearAll: {
                            viewModel.resetAllFilters()
                        }
                    )
                }

                // Main content
                Group {
                    if viewModel.isLoading {
                        ProgressView("Loading entries...")
                    } else if viewModel.filteredEntries.isEmpty && !viewModel.hasActiveFilters && viewModel.searchText.isEmpty {
                        // No entries at all
                        ContentUnavailableView {
                            Label("No Entries", systemImage: "doc.text")
                        } description: {
                            Text("Create your first entry using the + button")
                        }
                    } else if viewModel.filteredEntries.isEmpty && viewModel.hasActiveFilters {
                        // Empty due to filters
                        ContentUnavailableView {
                            Label("No Matching Entries", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text("No entries match your current filters. Try adjusting your filter settings.")
                        } actions: {
                            Button("Reset Filters") {
                                viewModel.resetAllFilters()
                            }
                        }
                    } else if viewModel.filteredEntries.isEmpty {
                        // Empty due to search
                        ContentUnavailableView.search
                    } else {
                        entriesList
                    }
                }
            }
            .navigationTitle("Entries")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        // Filter button
                        Button {
                            showFilterSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")

                                // Badge indicator when filters are active
                                if viewModel.hasActiveFilters {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }

                        // Settings button
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
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
            .sheet(isPresented: $showFilterSheet) {
                EntryFilterView(viewModel: viewModel)
            }
        } detail: {
            if let entry = selectedEntry {
                EntryDetailView(entry: entry)
                    .environmentObject(viewModel.vaultManager)
                    .id(entry.id) // Force refresh when entry changes
            } else {
                ContentUnavailableView {
                    Label("Select an Entry", systemImage: "doc.text")
                } description: {
                    Text("Choose an entry from the list to view its details")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedEntry) { _, _ in
            // Refresh entries when selection changes (entry may have been edited)
            Task {
                await viewModel.loadEntries()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(viewModel.vaultManager)
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete, entry.hasAttachments {
                    // Show second confirmation for attachments
                    showAttachmentDeleteConfirmation = true
                } else if let entry = entryToDelete {
                    // No attachments, delete immediately
                    Task {
                        do {
                            try await viewModel.deleteEntry(entry, deleteAttachments: false)
                            if selectedEntry?.id == entry.id {
                                selectedEntry = nil
                            }
                            entryToDelete = nil
                        } catch {
                            print("❌ Failed to delete entry: \(error)")
                        }
                    }
                }
            }
        } message: {
            Text("This will permanently delete the entry and cannot be undone.")
        }
        .alert("Also Delete Attachments?", isPresented: $showAttachmentDeleteConfirmation) {
            Button("Keep Attachments") {
                if let entry = entryToDelete {
                    Task {
                        do {
                            try await viewModel.deleteEntry(entry, deleteAttachments: false)
                            if selectedEntry?.id == entry.id {
                                selectedEntry = nil
                            }
                            entryToDelete = nil
                        } catch {
                            print("❌ Failed to delete entry: \(error)")
                        }
                    }
                }
            }
            Button("Delete Attachments", role: .destructive) {
                if let entry = entryToDelete {
                    Task {
                        do {
                            try await viewModel.deleteEntry(entry, deleteAttachments: true)
                            if selectedEntry?.id == entry.id {
                                selectedEntry = nil
                            }
                            entryToDelete = nil
                        } catch {
                            print("❌ Failed to delete entry: \(error)")
                        }
                    }
                }
            }
        } message: {
            if let entry = entryToDelete {
                let attachmentList = entry.attachmentTypes.joined(separator: ", ")
                Text("This entry has \(attachmentList). Do you want to delete them as well?")
            }
        }
    }

    private var entriesList: some View {
        List(selection: $selectedEntry) {
            ForEach(viewModel.entriesByDate(), id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        EntryRowView(entry: entry, placeCallout: viewModel.callout(for: entry.place), places: viewModel.places, people: viewModel.people, vaultURL: viewModel.vaultManager.vaultURL)
                            .tag(entry)
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
    var vaultURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with time, place, and entry type indicators (always at top)
            HStack {
                Text(entry.dateCreated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Photo indicator for photo entries
                if isPhotoEntry {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                        .imageScale(.small)
                }

                // Audio indicator for audio entries
                if isAudioEntry {
                    Image(systemName: "waveform")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .imageScale(.small)
                }

                // Running indicator for running entries
                if entry.isRunningEntry {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .imageScale(.small)
                }

                // Place indicator
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

            // Thumbnail and content section
            HStack(alignment: .top, spacing: 12) {
                // Photo thumbnail (if photo entry)
                if isPhotoEntry, let vaultURL, let photoFilename = entry.photoAttachment {
                    PhotoThumbnailView(vaultURL: vaultURL, filename: photoFilename)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                // Map thumbnail (if workout entry with route)
                else if entry.isWorkoutEntry, let vaultURL, let mapFilename = entry.mapAttachment {
                    MapThumbnailView(vaultURL: vaultURL, filename: mapFilename)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    // Content preview (with markdown + wiki-links, embeds removed)
                    MarkdownWikiText(
                        text: contentWithoutEmbeds,
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
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    /// Check if this is an audio entry
    private var isAudioEntry: Bool {
        entry.audioAttachments != nil && !(entry.audioAttachments?.isEmpty ?? true)
    }

    /// Check if this is a photo entry
    private var isPhotoEntry: Bool {
        entry.isPhotoEntry
    }

    /// Content with audio and photo embeds removed for cleaner display
    private var contentWithoutEmbeds: String {
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

        // Remove Obsidian photo embeds: ![[photos/filename.ext]]
        let photoEmbedPattern = #"!\[\[photos/[^\]]+\]\]"#
        if let regex = try? NSRegularExpression(pattern: photoEmbedPattern, options: []) {
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

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let vaultURL: URL
    let filename: String

    @State private var image: UIImage?

    private var photoURL: URL {
        vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("photos")
            .appendingPathComponent(filename)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let url = photoURL  // Capture URL before detached task
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // Load image on background thread
        let loadedImage = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data) else {
                return nil as UIImage?
            }

            // Create thumbnail for performance
            let maxSize: CGFloat = 120
            let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height)
            let newSize = CGSize(
                width: uiImage.size.width * scale,
                height: uiImage.size.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }.value

        await MainActor.run {
            self.image = loadedImage
        }
    }
}

// MARK: - Map Thumbnail View

struct MapThumbnailView: View {
    let vaultURL: URL
    let filename: String

    @State private var image: UIImage?

    private var mapURL: URL {
        vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("maps")
            .appendingPathComponent(filename)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "map")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let url = mapURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // Load image on background thread
        let loadedImage = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data) else {
                return nil as UIImage?
            }

            // Create thumbnail for performance (map PNGs are 800x600)
            let maxSize: CGFloat = 120
            let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height)
            let newSize = CGSize(
                width: uiImage.size.width * scale,
                height: uiImage.size.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }.value

        await MainActor.run {
            self.image = loadedImage
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
