//
//  iTunesSearchResult.swift
//  JournalCompanion
//
//  Response models for iTunes Search API
//

import Foundation

// MARK: - API Response

struct iTunesSearchResponse: Sendable {
    let resultCount: Int
    let results: [iTunesSearchItem]
}

extension iTunesSearchResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultCount = try container.decode(Int.self, forKey: .resultCount)
        results = try container.decode([iTunesSearchItem].self, forKey: .results)
    }

    private enum CodingKeys: String, CodingKey {
        case resultCount, results
    }
}

// MARK: - Search Result Item

struct iTunesSearchItem: Identifiable, Sendable {
    // Unique identifier (varies by type)
    var id: Int { trackId ?? collectionId ?? artistId ?? 0 }

    let trackId: Int?
    let collectionId: Int?
    let artistId: Int?

    // Title/Name fields
    let trackName: String?
    let collectionName: String?

    // Creator
    let artistName: String?

    // Artwork URLs
    let artworkUrl30: String?
    let artworkUrl60: String?
    let artworkUrl100: String?

    // Metadata
    let primaryGenreName: String?
    let releaseDate: String?
    let contentAdvisoryRating: String?

    // Duration/Counts
    let trackTimeMillis: Int?
    let trackCount: Int?
    let discCount: Int?

    // Links
    let trackViewUrl: String?
    let collectionViewUrl: String?
    let previewUrl: String?

    // Type info
    let kind: String?
    let wrapperType: String?

    // TV-specific
    let collectionExplicitness: String?
    let trackExplicitness: String?

    // Podcast-specific
    let feedUrl: String?

    // Book-specific
    let description: String?
    let genres: [String]?

    // MARK: - Computed Properties

    /// Unified title across all media types
    var displayTitle: String {
        // For albums, use collectionName
        // For movies/songs/episodes, use trackName
        // Fallback to collectionName if trackName is nil
        trackName ?? collectionName ?? "Unknown"
    }

    /// Unified creator name
    var displayCreator: String? {
        artistName
    }

    /// High-resolution artwork URL (replace size in URL)
    var displayArtworkURL: String? {
        // iTunes returns artworkUrl100 by default
        // We can modify the URL to get higher resolution (600x600)
        guard let url = artworkUrl100 else { return nil }
        return url.replacingOccurrences(of: "100x100", with: "600x600")
    }

    /// Store link URL
    var displayURL: String? {
        trackViewUrl ?? collectionViewUrl
    }

    /// Extract release year from ISO8601 date
    var releaseYear: Int? {
        guard let dateString = releaseDate else { return nil }

        // Try ISO8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return Calendar.current.component(.year, from: date)
        }

        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return Calendar.current.component(.year, from: date)
        }

        // Try basic date format (YYYY-MM-DD)
        let basicFormatter = DateFormatter()
        basicFormatter.dateFormat = "yyyy-MM-dd"
        if let date = basicFormatter.date(from: String(dateString.prefix(10))) {
            return Calendar.current.component(.year, from: date)
        }

        // Last resort: extract year from string
        if dateString.count >= 4, let year = Int(dateString.prefix(4)) {
            return year
        }

        return nil
    }

    /// Duration in minutes (for movies/songs)
    var durationMinutes: Int? {
        guard let millis = trackTimeMillis else { return nil }
        return millis / 60000
    }

    /// Convert to Media model
    func toMedia(type: MediaType) -> Media {
        var unknownFields: [String: YAMLValue] = [:]
        var unknownFieldsOrder: [String] = []

        // Add type-specific fields
        switch type {
        case .movie:
            if let minutes = durationMinutes {
                unknownFields["runtime_minutes"] = .int(minutes)
                unknownFieldsOrder.append("runtime_minutes")
            }
            if let rating = contentAdvisoryRating {
                unknownFields["content_rating"] = .string(rating)
                unknownFieldsOrder.append("content_rating")
            }
            unknownFields["date_watched"] = .string("")
            unknownFieldsOrder.append("date_watched")

        case .tvShow:
            if let count = trackCount {
                unknownFields["episode_count"] = .int(count)
                unknownFieldsOrder.append("episode_count")
            }

        case .album:
            if let count = trackCount {
                unknownFields["track_count"] = .int(count)
                unknownFieldsOrder.append("track_count")
            }
            if let discs = discCount, discs > 1 {
                unknownFields["disc_count"] = .int(discs)
                unknownFieldsOrder.append("disc_count")
            }

        case .podcast:
            if let feed = feedUrl {
                unknownFields["feed_url"] = .string(feed)
                unknownFieldsOrder.append("feed_url")
            }

        case .book:
            // Add date tracking fields for user to fill in
            unknownFields["date_started"] = .string("")
            unknownFieldsOrder.append("date_started")
            unknownFields["date_completed"] = .string("")
            unknownFieldsOrder.append("date_completed")

            if let desc = description, !desc.isEmpty {
                // Store description in content instead of unknownFields
            }
        }

        let title = displayTitle
        let sanitizedId = Media.sanitizeFilename(title)

        // Build tags array, including genres for books
        var tags = ["media", type.rawValue]
        if let genreList = genres {
            // Filter out generic terms like "Books" and sanitize for valid YAML
            let filteredGenres = genreList.compactMap { genre -> String? in
                let lowercased = genre.lowercased()
                if lowercased == "books" || lowercased == "ebooks" {
                    return nil
                }
                return Media.sanitizeTag(genre)
            }.filter { !$0.isEmpty }
            tags.append(contentsOf: filteredGenres)
        }

        return Media(
            id: sanitizedId,
            title: title,
            mediaType: type,
            creator: displayCreator,
            releaseYear: releaseYear,
            genre: primaryGenreName ?? genres?.first,
            artworkURL: displayArtworkURL,
            iTunesID: String(id),
            iTunesURL: displayURL,
            tags: tags,
            aliases: [],
            content: type == .book ? (description ?? "") : "",
            unknownFields: unknownFields,
            unknownFieldsOrder: unknownFieldsOrder
        )
    }
}

extension iTunesSearchItem: Decodable {
    private enum CodingKeys: String, CodingKey {
        case trackId, collectionId, artistId
        case trackName, collectionName, artistName
        case artworkUrl30, artworkUrl60, artworkUrl100
        case primaryGenreName, releaseDate, contentAdvisoryRating
        case trackTimeMillis, trackCount, discCount
        case trackViewUrl, collectionViewUrl, previewUrl
        case kind, wrapperType
        case collectionExplicitness, trackExplicitness
        case feedUrl, description, genres
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackId = try container.decodeIfPresent(Int.self, forKey: .trackId)
        collectionId = try container.decodeIfPresent(Int.self, forKey: .collectionId)
        artistId = try container.decodeIfPresent(Int.self, forKey: .artistId)
        trackName = try container.decodeIfPresent(String.self, forKey: .trackName)
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName)
        artworkUrl30 = try container.decodeIfPresent(String.self, forKey: .artworkUrl30)
        artworkUrl60 = try container.decodeIfPresent(String.self, forKey: .artworkUrl60)
        artworkUrl100 = try container.decodeIfPresent(String.self, forKey: .artworkUrl100)
        primaryGenreName = try container.decodeIfPresent(String.self, forKey: .primaryGenreName)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        contentAdvisoryRating = try container.decodeIfPresent(String.self, forKey: .contentAdvisoryRating)
        trackTimeMillis = try container.decodeIfPresent(Int.self, forKey: .trackTimeMillis)
        trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        discCount = try container.decodeIfPresent(Int.self, forKey: .discCount)
        trackViewUrl = try container.decodeIfPresent(String.self, forKey: .trackViewUrl)
        collectionViewUrl = try container.decodeIfPresent(String.self, forKey: .collectionViewUrl)
        previewUrl = try container.decodeIfPresent(String.self, forKey: .previewUrl)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        wrapperType = try container.decodeIfPresent(String.self, forKey: .wrapperType)
        collectionExplicitness = try container.decodeIfPresent(String.self, forKey: .collectionExplicitness)
        trackExplicitness = try container.decodeIfPresent(String.self, forKey: .trackExplicitness)
        feedUrl = try container.decodeIfPresent(String.self, forKey: .feedUrl)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
    }
}

// MARK: - Errors

enum iTunesSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from iTunes"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noResults:
            return "No results found"
        }
    }
}
