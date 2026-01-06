//
//  MediaListView.swift
//  JournalCompanion
//
//  Main list view for browsing saved media
//

import SwiftUI

struct MediaListView: View {
    @ObservedObject var viewModel: MediaListViewModel
    @EnvironmentObject var vaultManager: VaultManager
    @State private var selectedMedia: Media?

    var body: some View {
        NavigationSplitView {
            listContent
                .navigationTitle("Media")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        filterMenu
                    }
                }
                .refreshable {
                    await viewModel.reloadMedia()
                }
        } detail: {
            if let media = selectedMedia {
                MediaDetailView(media: media)
            } else {
                ContentUnavailableView("Select Media", systemImage: "play.rectangle.on.rectangle", description: Text("Choose a media item from the list"))
            }
        }
        .task {
            await viewModel.loadMediaIfNeeded()
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading media...")
        } else if viewModel.media.isEmpty {
            ContentUnavailableView("No Media", systemImage: "play.rectangle.on.rectangle", description: Text("Add media using the + button"))
        } else if viewModel.filteredMedia.isEmpty {
            ContentUnavailableView("No Results", systemImage: "line.3.horizontal.decrease.circle", description: Text("No media matches your filter"))
        } else {
            List(selection: $selectedMedia) {
                // Group by type
                ForEach(viewModel.mediaByType, id: \.type) { group in
                    Section {
                        ForEach(group.items) { item in
                            NavigationLink(value: item) {
                                MediaRow(media: item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteMedia(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: group.type.systemImage)
                                .foregroundStyle(group.type.color)
                            Text(group.type.displayName + "s")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Filter by Type") {
                ForEach(MediaType.allCases, id: \.self) { type in
                    Button {
                        viewModel.toggleType(type)
                    } label: {
                        Label {
                            Text(type.displayName)
                        } icon: {
                            Image(systemName: viewModel.isTypeSelected(type) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }

            if !viewModel.selectedTypes.isEmpty {
                Divider()

                Button("Clear Filters") {
                    viewModel.clearTypeFilters()
                }
            }
        } label: {
            Image(systemName: viewModel.selectedTypes.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func deleteMedia(_ media: Media) {
        Task {
            do {
                try await viewModel.deleteMedia(media)
                if selectedMedia == media {
                    selectedMedia = nil
                }
            } catch {
                print("Failed to delete media: \(error)")
            }
        }
    }
}
