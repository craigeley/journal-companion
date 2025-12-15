//
//  EntryListView.swift
//  JournalCompanion
//
//  Browse and search journal entries
//

import SwiftUI

struct EntryListView: View {
    @StateObject var viewModel: EntryListViewModel
    @Environment(\.dismiss) var dismiss

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
            .searchable(text: $viewModel.searchText, prompt: "Search entries")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
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
        }
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.entriesByDate(), id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        EntryRowView(entry: entry)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with time and place
            HStack {
                Text(entry.dateCreated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let place = entry.place {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
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

            // Content preview
            Text(entry.content)
                .font(.body)
                .lineLimit(3)

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
    let viewModel = EntryListViewModel(vaultManager: vaultManager)
    return EntryListView(viewModel: viewModel)
}
