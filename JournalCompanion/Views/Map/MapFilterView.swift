//
//  MapFilterView.swift
//  JournalCompanion
//
//  Filter controls for MapView
//

import SwiftUI

struct MapFilterView: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Callout Types Section
                calloutTypesSection

                // Tags Section (only if tags exist)
                if !viewModel.availableTags.isEmpty {
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
                        viewModel.resetFilters()
                    }
                    .disabled(!viewModel.hasActiveFilters)
                }
            }
        }
    }

    // MARK: - Callout Types Section

    private var calloutTypesSection: some View {
        Section {
            ForEach(viewModel.allCalloutTypes, id: \.self) { callout in
                CalloutTypeRow(
                    callout: callout,
                    isSelected: viewModel.selectedCalloutTypes.contains(callout)
                ) {
                    viewModel.toggleCalloutType(callout)
                }
            }
        } header: {
            HStack {
                Text("Place Types")
                Spacer()
                Text("\(viewModel.selectedCalloutTypes.count)/\(viewModel.allCalloutTypes.count)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } footer: {
            HStack(spacing: 16) {
                Button("Select All") {
                    viewModel.selectAllCalloutTypes()
                }
                .disabled(viewModel.selectedCalloutTypes.count == viewModel.allCalloutTypes.count)

                Button("Deselect All") {
                    viewModel.deselectAllCalloutTypes()
                }
                .disabled(viewModel.selectedCalloutTypes.isEmpty)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        Section {
            ForEach(viewModel.availableTags, id: \.self) { tag in
                TagRow(
                    tag: tag,
                    isSelected: viewModel.selectedTags.contains(tag)
                ) {
                    viewModel.toggleTag(tag)
                }
            }
        } header: {
            HStack {
                Text("Tags")
                Spacer()
                Text("\(viewModel.selectedTags.count)/\(viewModel.availableTags.count)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } footer: {
            HStack(spacing: 16) {
                Button("Select All") {
                    viewModel.selectAllTags()
                }
                .disabled(viewModel.selectedTags.count == viewModel.availableTags.count)

                Button("Deselect All") {
                    viewModel.deselectAllTags()
                }
                .disabled(viewModel.selectedTags.isEmpty)
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
                Text("\(viewModel.filteredPlaces.count)")
                    .font(.headline)
                    .foregroundStyle(viewModel.filteredPlaces.isEmpty ? .red : .primary)
            }
        } footer: {
            if viewModel.filteredPlaces.isEmpty {
                Text("No places match the current filters. Try adjusting your selection.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Callout Type Row

struct CalloutTypeRow: View {
    let callout: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Icon with background circle (similar to PlaceMapPin)
                ZStack {
                    Circle()
                        .fill(PlaceIcon.color(for: callout))
                        .frame(width: 32, height: 32)

                    Image(systemName: PlaceIcon.systemName(for: callout))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(callout.capitalized)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text("#\(tag)")
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let vaultManager = VaultManager()
    let viewModel = MapViewModel(vaultManager: vaultManager)
    return MapFilterView(viewModel: viewModel)
}
