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
    @EnvironmentObject var templateManager: TemplateManager

    @State private var recentEntries: [Entry] = []
    @State private var isLoadingEntries = false
    @State private var selectedEntry: Entry?
    @State private var showEntryDetail = false
    @State private var showPlaceEdit = false

    var body: some View {
        NavigationStack {
            List {
                // Header Section with Icon
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: PlaceIcon.systemName(for: place.callout))
                                .font(.system(size: 60))
                                .foregroundStyle(PlaceIcon.color(for: place.callout))

                            Text(place.name)
                                .font(.title2)
                                .bold()

                            Text(place.callout.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Location Info
                if let address = place.address {
                    Section("Address") {
                        Text(address)
                    }
                }

                if let location = place.location {
                    Section("Coordinates") {
                        LabeledContent("Latitude", value: String(format: "%.6f", location.latitude))
                        LabeledContent("Longitude", value: String(format: "%.6f", location.longitude))
                    }
                }

                // Tags
                if !place.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(place.tags.filter { $0 != "place" }, id: \.self) { tag in
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
                if !place.aliases.isEmpty {
                    Section("Aliases") {
                        ForEach(place.aliases, id: \.self) { alias in
                            Text(alias)
                        }
                    }
                }

                // URL
                if let urlString = place.url, let url = URL(string: urlString) {
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

                                WikiText(
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
                    place: place,
                    vaultManager: vaultManager,
                    templateManager: templateManager
                ))
                .environmentObject(templateManager)
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
            let placeEntries = allEntries.filter { $0.place == place.name }

            // Take 5 most recent (already sorted newest first)
            recentEntries = Array(placeEntries.prefix(5))
        } catch {
            print("❌ Failed to load entries for place: \(error)")
            recentEntries = []
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
