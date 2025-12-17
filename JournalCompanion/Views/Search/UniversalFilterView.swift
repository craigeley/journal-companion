//
//  UniversalFilterView.swift
//  JournalCompanion
//
//  Filter controls for Places search (uses SearchCoordinator)
//

import SwiftUI

struct UniversalFilterView: View {
    @ObservedObject var coordinator: SearchCoordinator
    @ObservedObject var placesViewModel: PlacesListViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Callout Types Section
                calloutTypesSection

                // Tags Section (only if tags exist)
                if !coordinator.availableTags.isEmpty {
                    tagsSection
                }

                // Summary Section
                summarySection
            }
            .navigationTitle("Filter Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset All") {
                        coordinator.resetFilters()
                    }
                    .disabled(!coordinator.hasActiveFilters)
                }
            }
            .onAppear {
                // Update available tags from places
                coordinator.updateAvailableTags(from: placesViewModel.places)
            }
        }
    }

    // MARK: - Callout Types Section

    private var calloutTypesSection: some View {
        Section {
            ForEach(coordinator.allCalloutTypes, id: \.self) { callout in
                CalloutTypeRow(
                    callout: callout,
                    isSelected: coordinator.selectedCalloutTypes.contains(callout)
                ) {
                    coordinator.toggleCalloutType(callout)
                }
            }
        } header: {
            HStack {
                Text("Place Types")
                Spacer()
                Text("\(coordinator.selectedCalloutTypes.count)/\(coordinator.allCalloutTypes.count)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } footer: {
            HStack(spacing: 16) {
                Button("Select All") {
                    coordinator.selectAllCalloutTypes()
                }
                .disabled(coordinator.selectedCalloutTypes.count == coordinator.allCalloutTypes.count)

                Button("Deselect All") {
                    coordinator.deselectAllCalloutTypes()
                }
                .disabled(coordinator.selectedCalloutTypes.isEmpty)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        Section {
            ForEach(coordinator.availableTags, id: \.self) { tag in
                TagRow(
                    tag: tag,
                    isSelected: coordinator.selectedTags.contains(tag)
                ) {
                    coordinator.toggleTag(tag)
                }
            }
        } header: {
            HStack {
                Text("Tags")
                Spacer()
                Text("\(coordinator.selectedTags.count)/\(coordinator.availableTags.count)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } footer: {
            HStack(spacing: 16) {
                Button("Select All") {
                    coordinator.selectAllTags()
                }
                .disabled(coordinator.selectedTags.count == coordinator.availableTags.count)

                Button("Deselect All") {
                    coordinator.deselectAllTags()
                }
                .disabled(coordinator.selectedTags.isEmpty)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            HStack {
                Label("Showing Places", systemImage: "mappin.circle.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(placesViewModel.filteredPlaces.count)")
                    .font(.headline)
                    .foregroundStyle(placesViewModel.filteredPlaces.isEmpty ? .red : .primary)
            }
        } footer: {
            if placesViewModel.filteredPlaces.isEmpty {
                Text("No places match the current filters. Try adjusting your selection.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
