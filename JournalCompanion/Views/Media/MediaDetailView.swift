//
//  MediaDetailView.swift
//  JournalCompanion
//
//  View for displaying media details
//

import SwiftUI

struct MediaDetailView: View {
    let media: Media
    @EnvironmentObject var vaultManager: VaultManager
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with artwork
                headerSection

                // Metadata
                metadataSection

                // Tags
                if !media.tags.isEmpty {
                    tagsSection
                }

                // Notes/Review
                if !media.content.isEmpty {
                    notesSection
                }

                // Links
                linksSection
            }
            .padding()
        }
        .navigationTitle(media.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            MediaEditView(viewModel: MediaEditViewModel(
                vaultManager: vaultManager,
                media: media
            ))
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Artwork
            artworkView
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)

            // Title and creator
            VStack(spacing: 4) {
                Text(media.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let creator = media.creator {
                    Text(creator)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            // Type badge
            HStack(spacing: 4) {
                Image(systemName: media.mediaType.systemImage)
                Text(media.mediaType.displayName)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(media.mediaType.color.opacity(0.2))
            .foregroundStyle(media.mediaType.color)
            .clipShape(Capsule())
        }
    }

    private var metadataSection: some View {
        VStack(spacing: 12) {
            if let year = media.releaseYear {
                metadataRow(label: "Year", value: String(year))
            }

            if let genre = media.genre {
                metadataRow(label: "Genre", value: genre)
            }

            // Type-specific metadata from unknownFields
            ForEach(media.unknownFieldsOrder, id: \.self) { key in
                if let value = media.unknownFields[key] {
                    metadataRow(label: formatFieldName(key), value: formatFieldValue(value))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(media.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)

            Text(media.content)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var linksSection: some View {
        VStack(spacing: 12) {
            if let urlString = media.iTunesURL, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("View on iTunes")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let urlString = media.artworkURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderView
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            Rectangle()
                .fill(media.mediaType.color.opacity(0.2))
            Image(systemName: media.mediaType.systemImage)
                .font(.system(size: 60))
                .foregroundStyle(media.mediaType.color)
        }
    }

    // MARK: - Helpers

    private func formatFieldName(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func formatFieldValue(_ value: YAMLValue) -> String {
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(format: "%.1f", d)
        case .bool(let b): return b ? "Yes" : "No"
        case .array(let arr): return arr.joined(separator: ", ")
        case .date(let d):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: d)
        }
    }
}
