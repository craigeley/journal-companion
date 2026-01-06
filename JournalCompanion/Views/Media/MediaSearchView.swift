//
//  MediaSearchView.swift
//  JournalCompanion
//
//  View for searching iTunes and selecting media to add
//

import SwiftUI

struct MediaSearchView: View {
    @StateObject private var viewModel = MediaSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    // Callback when user selects a result
    let onSelect: (iTunesSearchItem, MediaType) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Media type picker
                mediaTypePicker
                    .padding()

                // Search bar
                searchBar
                    .padding(.horizontal)

                // Results
                resultsView
            }
            .navigationTitle("Search Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var mediaTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MediaType.allCases, id: \.self) { type in
                    Button {
                        viewModel.selectedMediaType = type
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.systemImage)
                            Text(type.displayName)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedMediaType == type
                                ? type.color.opacity(0.2)
                                : Color(.systemGray6)
                        )
                        .foregroundStyle(
                            viewModel.selectedMediaType == type
                                ? type.color
                                : .primary
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search \(viewModel.selectedMediaType.displayName.lowercased())s...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var resultsView: some View {
        if viewModel.isSearching && viewModel.searchResults.isEmpty {
            Spacer()
            ProgressView("Searching...")
            Spacer()
        } else if let error = viewModel.errorMessage {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else if viewModel.hasSearched && viewModel.searchResults.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No results found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else if viewModel.searchResults.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: viewModel.selectedMediaType.systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Search for \(viewModel.selectedMediaType.displayName.lowercased())s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            List(viewModel.searchResults) { result in
                Button {
                    onSelect(result, viewModel.selectedMediaType)
                    dismiss()
                } label: {
                    iTunesResultRow(result: result, mediaType: viewModel.selectedMediaType)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}
