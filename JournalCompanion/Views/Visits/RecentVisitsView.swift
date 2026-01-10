//
//  RecentVisitsView.swift
//  JournalCompanion
//
//  UI for browsing and selecting recent location visits
//

import SwiftUI

struct RecentVisitsView: View {
    @StateObject var viewModel: RecentVisitsViewModel
    @Environment(\.dismiss) var dismiss

    let onVisitSelected: (PersistedVisit) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.visits.isEmpty {
                    ContentUnavailableView {
                        Label("No Recent Visits", systemImage: "mappin.slash")
                    } description: {
                        Text("Visit tracking will record locations you spend time at")
                    }
                } else {
                    visitsList
                }
            }
            .navigationTitle("Recent Visits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var visitsList: some View {
        List {
            ForEach(viewModel.visitsByDate(), id: \.date) { section in
                Section(header: Text(viewModel.sectionHeader(for: section.date))) {
                    ForEach(section.visits) { visit in
                        VisitRow(visit: visit, viewModel: viewModel) {
                            onVisitSelected(visit)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct VisitRow: View {
    let visit: PersistedVisit
    let viewModel: RecentVisitsViewModel
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: visit.matchedPlaceName != nil ? "mappin.circle.fill" : "mappin.circle")
                    .foregroundStyle(visit.matchedPlaceName != nil ? .blue : .secondary)
                    .font(.title2)
                    .frame(width: 32)

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    // Place name or coordinates
                    if let placeName = visit.matchedPlaceName {
                        Text(placeName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    } else {
                        Text(String(format: "%.4f, %.4f", visit.latitude, visit.longitude))
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    // Time range
                    Text(viewModel.timeRange(for: visit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Duration
                    Label(visit.durationString, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
