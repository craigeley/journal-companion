//
//  MediaRow.swift
//  JournalCompanion
//
//  Row component for displaying media in a list
//

import SwiftUI

struct MediaRow: View {
    let media: Media

    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail
            artworkView
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(media.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    // Media type icon
                    Image(systemName: media.mediaType.systemImage)
                        .foregroundStyle(media.mediaType.color)
                        .font(.caption)

                    if let creator = media.creator {
                        Text(creator)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let year = media.releaseYear {
                        Text("(\(String(year)))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
                .font(.title2)
                .foregroundStyle(media.mediaType.color)
        }
    }
}

// MARK: - iTunes Search Result Row

struct iTunesResultRow: View {
    let result: iTunesSearchItem
    let mediaType: MediaType

    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail
            artworkView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let creator = result.displayCreator {
                    Text(creator)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let year = result.releaseYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let genre = result.primaryGenreName {
                        Text(genre)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let urlString = result.displayArtworkURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
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
                .fill(mediaType.color.opacity(0.2))
            Image(systemName: mediaType.systemImage)
                .font(.title2)
                .foregroundStyle(mediaType.color)
        }
    }
}
