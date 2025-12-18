//
//  PlaceDetailView.swift
//  JournalCompanion
//
//  Detail view for displaying comprehensive place information
//

import SwiftUI
import CoreLocation

struct PlaceDetailView: View {
    let place: Place
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager

    @State private var currentPlace: Place
    @State private var recentEntries: [Entry] = []
    @State private var isLoadingEntries = false
    @State private var selectedEntry: Entry?
    @State private var showEntryDetail = false
    @State private var showPlaceEdit = false

    init(place: Place) {
        self.place = place
        _currentPlace = State(initialValue: place)
    }

    var body: some View {
        NavigationStack {
            List {
                // Header Section with Icon
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: PlaceIcon.systemName(for: currentPlace.callout))
                                .font(.system(size: 60))
                                .foregroundStyle(PlaceIcon.color(for: currentPlace.callout))

                            Text(currentPlace.name)
                                .font(.title2)
                                .bold()

                            Text(currentPlace.callout.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Location Info
                if templateManager.placeTemplate.isEnabled("addr"),
                   let address = currentPlace.address {
                    Section("Address") {
                        Text(address)
                    }
                }

                if templateManager.placeTemplate.isEnabled("location"),
                   let location = currentPlace.location {
                    Section("Coordinates") {
                        LabeledContent("Latitude", value: String(format: "%.6f", location.latitude))
                        LabeledContent("Longitude", value: String(format: "%.6f", location.longitude))
                    }
                }

                // Tags
                if templateManager.placeTemplate.isEnabled("tags") && !currentPlace.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(currentPlace.tags.filter { $0 != "place" }, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Aliases
                if templateManager.placeTemplate.isEnabled("aliases") && !currentPlace.aliases.isEmpty {
                    Section("Aliases") {
                        ForEach(currentPlace.aliases, id: \.self) { alias in
                            Text(alias)
                        }
                    }
                }

                // URL
                if templateManager.placeTemplate.isEnabled("url"),
                   let urlString = currentPlace.url,
                   let url = URL(string: urlString) {
                    Section("Link") {
                        Link(destination: url) {
                            HStack {
                                Text(urlString)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // Notes
                if !currentPlace.content.isEmpty {
                    Section("Notes") {
                        MarkdownWikiText(
                            text: currentPlace.content,
                            places: vaultManager.places,
                            people: vaultManager.people,
                            lineLimit: nil,
                            font: .body
                        )
                    }
                }

                // Recent Entries
                Section("Recent Entries") {
                    if isLoadingEntries {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if recentEntries.isEmpty {
                        Text("No entries yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.dateCreated, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(entry.dateCreated, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                MarkdownWikiText(
                                    text: entry.content,
                                    places: vaultManager.places,
                                    people: vaultManager.people,
                                    lineLimit: 2,
                                    font: .body
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                                showEntryDetail = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showPlaceEdit = true
                    }
                }
            }
            .task {
                await loadRecentEntries()
            }
            .sheet(isPresented: $showEntryDetail) {
                if let entry = selectedEntry {
                    EntryDetailView(entry: entry)
                        .environmentObject(vaultManager)
                }
            }
            .onChange(of: showEntryDetail) { _, isShowing in
                if !isShowing {
                    // Reload entries when entry detail view closes
                    Task {
                        await loadRecentEntries()
                    }
                }
            }
            .sheet(isPresented: $showPlaceEdit) {
                PlaceEditView(viewModel: PlaceEditViewModel(
                    place: currentPlace,
                    vaultManager: vaultManager,
                    locationService: locationService,
                    templateManager: templateManager
                ))
                .environmentObject(templateManager)
            }
            .onChange(of: showPlaceEdit) { _, isShowing in
                if !isShowing {
                    // Reload place when edit view closes
                    Task {
                        await reloadPlace()
                    }
                }
            }
        }
    }

    private func loadRecentEntries() async {
        isLoadingEntries = true
        defer { isLoadingEntries = false }

        guard let vaultURL = vaultManager.vaultURL else { return }

        do {
            let reader = EntryReader(vaultURL: vaultURL)
            let allEntries = try await reader.loadEntries(limit: 100)

            // Filter entries that reference this place
            let placeEntries = allEntries.filter { $0.place == currentPlace.name }

            // Take 5 most recent (already sorted newest first)
            recentEntries = Array(placeEntries.prefix(5))
        } catch {
            print("❌ Failed to load entries for place: \(error)")
            recentEntries = []
        }
    }

    private func reloadPlace() async {
        // Reload places from vault to get updated place
        do {
            _ = try await vaultManager.loadPlaces()
            // Find the updated place by ID
            if let updatedPlace = vaultManager.places.first(where: { $0.id == currentPlace.id }) {
                currentPlace = updatedPlace
            }
        } catch {
            print("❌ Failed to reload place: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    let samplePlace = Place(
        id: "sample-cafe",
        name: "Sample Cafe",
        location: nil,
        address: "123 Main Street, San Francisco, CA",
        tags: ["coffee", "wifi", "cafe"],
        callout: "cafe",
        pin: "mappin.circle.fill",
        color: "orange",
        url: "https://example.com",
        aliases: ["The Sample", "Sample Coffee Shop"],
        content: ""
    )
    PlaceDetailView(place: samplePlace)
}
