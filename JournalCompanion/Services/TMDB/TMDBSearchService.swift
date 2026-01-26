//
//  TMDBSearchService.swift
//  JournalCompanion
//
//  Network service for TMDB (The Movie Database) API
//  Returns iTunesSearchItem to maintain compatibility with existing views
//

import Foundation

actor TMDBSearchService {
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p/w500"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Search TMDB for movies, returning results as iTunesSearchItem for view compatibility
    func search(term: String, limit: Int = 25) async throws -> [iTunesSearchItem] {
        guard var components = URLComponents(string: "\(baseURL)/search/movie") else {
            throw TMDBSearchError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "query", value: term),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1")
        ]

        guard let url = components.url else {
            throw TMDBSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(TMDBConfig.apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("🔍 TMDB Search: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TMDBSearchError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ TMDB API returned status: \(httpResponse.statusCode)")
                throw TMDBSearchError.invalidResponse
            }

            let searchResponse = try decodeResponse(data)

            print("✓ TMDB returned \(searchResponse.results.count) results")

            let items = Array(searchResponse.results.prefix(limit)).map { movie in
                movie.toiTunesSearchItem(imageBaseURL: imageBaseURL)
            }

            return items
        } catch let error as TMDBSearchError {
            throw error
        } catch let error as DecodingError {
            print("❌ TMDB decoding error: \(error)")
            throw TMDBSearchError.invalidResponse
        } catch {
            print("❌ TMDB network error: \(error)")
            throw TMDBSearchError.networkError(error)
        }
    }

    private nonisolated func decodeResponse(_ data: Data) throws -> TMDBSearchResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TMDBSearchResponse.self, from: data)
    }
}

// MARK: - TMDB Response Models

private struct TMDBSearchResponse: Sendable {
    let page: Int
    let results: [TMDBMovie]
    let totalResults: Int
    let totalPages: Int
}

extension TMDBSearchResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decode(Int.self, forKey: .page)
        results = try container.decode([TMDBMovie].self, forKey: .results)
        totalResults = try container.decode(Int.self, forKey: .totalResults)
        totalPages = try container.decode(Int.self, forKey: .totalPages)
    }

    private enum CodingKeys: String, CodingKey {
        case page, results, totalResults, totalPages
    }
}

private struct TMDBMovie: Sendable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let genreIds: [Int]?
    let voteAverage: Double?
    let adult: Bool?

    nonisolated func toiTunesSearchItem(imageBaseURL: String) -> iTunesSearchItem {
        let artworkURL: String? = posterPath.map { imageBaseURL + $0 }
        let genreName = genreIds?.first.flatMap { TMDBGenres.name(for: $0) }
        let tmdbWebURL = "https://www.themoviedb.org/movie/\(id)"

        return iTunesSearchItem(
            trackId: id,
            collectionId: nil,
            artistId: nil,
            trackName: title,
            collectionName: nil,
            artistName: nil,
            artworkUrl30: nil,
            artworkUrl60: nil,
            artworkUrl100: artworkURL,
            primaryGenreName: genreName,
            releaseDate: releaseDate,
            contentAdvisoryRating: nil,
            trackTimeMillis: nil,
            trackCount: nil,
            discCount: nil,
            trackViewUrl: tmdbWebURL,
            collectionViewUrl: nil,
            previewUrl: nil,
            kind: "feature-movie",
            wrapperType: "track",
            collectionExplicitness: nil,
            trackExplicitness: nil,
            feedUrl: nil,
            description: overview,
            genres: nil
        )
    }
}

extension TMDBMovie: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        genreIds = try container.decodeIfPresent([Int].self, forKey: .genreIds)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        adult = try container.decodeIfPresent(Bool.self, forKey: .adult)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, overview, posterPath, releaseDate, genreIds, voteAverage, adult
    }
}

// MARK: - TMDB Genre Mapping

private enum TMDBGenres {
    nonisolated static func name(for id: Int) -> String? {
        genreMap[id]
    }

    // TMDB movie genre IDs are stable and rarely change
    nonisolated private static let genreMap: [Int: String] = [
        28: "Action",
        12: "Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10751: "Family",
        14: "Fantasy",
        36: "History",
        27: "Horror",
        10402: "Music",
        9648: "Mystery",
        10749: "Romance",
        878: "Science Fiction",
        10770: "TV Movie",
        53: "Thriller",
        10752: "War",
        37: "Western",
    ]
}

// MARK: - Errors

enum TMDBSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from TMDB"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
