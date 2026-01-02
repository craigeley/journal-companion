//
//  EntryFilterChipsView.swift
//  JournalCompanion
//
//  Displays active filter chips with remove buttons
//

import SwiftUI

/// Displays active filter chips with remove buttons
struct EntryFilterChipsView: View {
    let chips: [FilterChip]
    let onClearAll: () -> Void

    var body: some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Filters")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Clear All") {
                        onClearAll()
                    }
                    .font(.caption)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips) { chip in
                            FilterChipView(chip: chip)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

/// Individual filter chip with remove button
struct FilterChipView: View {
    let chip: FilterChip

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: chip.systemImage)
                .font(.caption2)

            Text(chip.label)
                .font(.subheadline)

            Button(action: chip.onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .foregroundStyle(.primary)
        .clipShape(Capsule())
    }
}

#Preview {
    let sampleChips = [
        FilterChip(id: "1", label: "Jan 15, 2025", systemImage: "calendar", onRemove: {}),
        FilterChip(id: "2", label: "Photo", systemImage: "photo.fill", onRemove: {}),
        FilterChip(id: "3", label: "Workout", systemImage: "figure.run", onRemove: {})
    ]

    return EntryFilterChipsView(chips: sampleChips, onClearAll: {})
}
