//
//  EntryFilterView.swift
//  JournalCompanion
//
//  Filter controls for EntryListView (calendar + entry types)
//

import SwiftUI

/// Filter controls for EntryListView (calendar + entry types)
struct EntryFilterView: View {
    @ObservedObject var viewModel: EntryListViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Calendar Section
                calendarSection

                // Entry Types Section
                entryTypesSection

                // Summary Section
                summarySection
            }
            .navigationTitle("Filter Entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset All") {
                        viewModel.resetAllFilters()
                    }
                    .disabled(!viewModel.hasActiveFilters)
                }
            }
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        Section {
            VStack(spacing: 12) {
                if let selectedDate = viewModel.selectedDate {
                    DatePicker("", selection: Binding(
                        get: { selectedDate },
                        set: { viewModel.selectedDate = Calendar.current.startOfDay(for: $0) }
                    ), in: viewModel.calendarDateRange, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                    Button("Clear Date Filter") {
                        viewModel.clearDateFilter()
                    }
                    .font(.subheadline)
                } else {
                    DatePicker("", selection: Binding(
                        get: { Date() },
                        set: { viewModel.selectedDate = Calendar.current.startOfDay(for: $0) }
                    ), in: viewModel.calendarDateRange, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                }
            }
        } header: {
            HStack {
                Text("Date")
                Spacer()
                if let date = viewModel.selectedDate {
                    Text(date, style: .date)
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                }
            }
        } footer: {
            Text("Tap a date to filter entries from that day.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Entry Types Section

    private var entryTypesSection: some View {
        Section {
            ForEach(viewModel.allEntryTypes, id: \.self) { type in
                EntryTypeRow(
                    type: type,
                    isSelected: viewModel.selectedEntryTypes.contains(type),
                    count: entryCount(for: type)
                ) {
                    viewModel.toggleEntryType(type)
                }
            }
        } header: {
            HStack {
                Text("Entry Types")
                Spacer()
                Text("\(viewModel.selectedEntryTypes.count)/\(viewModel.allEntryTypes.count)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } footer: {
            HStack(spacing: 16) {
                Button("Select All") {
                    viewModel.selectedEntryTypes = Set(viewModel.allEntryTypes)
                }
                .disabled(viewModel.selectedEntryTypes.count == viewModel.allEntryTypes.count)

                Button("Deselect All") {
                    viewModel.clearEntryTypeFilters()
                    viewModel.selectedEntryTypes.removeAll()
                }
                .disabled(viewModel.selectedEntryTypes.isEmpty)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            HStack {
                Label("Showing Entries", systemImage: "doc.text.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.filteredEntries.count)")
                    .font(.headline)
                    .foregroundStyle(viewModel.filteredEntries.isEmpty ? .red : .primary)
            }
        } footer: {
            if viewModel.filteredEntries.isEmpty && viewModel.hasActiveFilters {
                Text("No entries match the current filters. Try adjusting your selection.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helper Methods

    /// Count entries of a specific type (respecting date filter if active)
    private func entryCount(for type: Entry.EntryType) -> Int {
        var entries = viewModel.entries

        // Apply date filter if active
        if let selectedDate = viewModel.selectedDate {
            let calendar = Calendar.current
            let targetDay = calendar.startOfDay(for: selectedDate)
            entries = entries.filter { calendar.startOfDay(for: $0.dateCreated) == targetDay }
        }

        return entries.filter { $0.entryType == type }.count
    }
}

// MARK: - Entry Type Row

struct EntryTypeRow: View {
    let type: Entry.EntryType
    let isSelected: Bool
    let count: Int
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: type.systemImage)
                    .font(.title3)
                    .foregroundStyle(type.color)
                    .frame(width: 32)

                Text(type.rawValue)
                    .foregroundStyle(.primary)

                Spacer()

                // Count badge
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())

                // Checkbox
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
    let locationService = LocationService()
    let viewModel = EntryListViewModel(vaultManager: vaultManager, locationService: locationService)
    return EntryFilterView(viewModel: viewModel)
}
