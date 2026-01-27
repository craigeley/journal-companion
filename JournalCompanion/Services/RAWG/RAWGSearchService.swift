//
//  RAWGSearchService.swift
//  JournalCompanion
//
//  Network service for RAWG Video Games Database API
//  Returns iTunesSearchItem to maintain compatibility with existing views
//

import Foundation

actor RAWGSearchService {
    private let baseURL = "https://api.rawg.io/api"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Search RAWG for video games, returning results as iTunesSearchItem for view compatibility
    func search(term: String, limit: Int = 25) async throws -> [iTunesSearchItem] {
        guard var components = URLComponents(string: "\(baseURL)/games") else {
            throw RAWGSearchError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: RAWGConfig.apiKey),
            URLQueryItem(name: "search", value: term),
            URLQueryItem(name: "page_size", value: String(limit))
        ]

        guard let url = components.url else {
            throw RAWGSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("🔍 RAWG Search: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RAWGSearchError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ RAWG API returned status: \(httpResponse.statusCode)")
                throw RAWGSearchError.invalidResponse
            }

            let searchResponse = try decodeResponse(data)

            print("✓ RAWG returned \(searchResponse.results.count) results")

            let items = searchResponse.results.map { game in
                game.toiTunesSearchItem()
            }

            return items
        } catch let error as RAWGSearchError {
            throw error
        } catch let error as DecodingError {
            print("❌ RAWG decoding error: \(error)")
            throw RAWGSearchError.invalidResponse
        } catch {
            print("❌ RAWG network error: \(error)")
            throw RAWGSearchError.networkError(error)
        }
    }

    private nonisolated func decodeResponse(_ data: Data) throws -> RAWGSearchResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RAWGSearchResponse.self, from: data)
    }
}

// MARK: - RAWG Response Models

struct RAWGSearchResponse: Sendable {
    let count: Int
    let results: [RAWGGame]
}

extension RAWGSearchResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decode(Int.self, forKey: .count)
        results = try container.decode([RAWGGame].self, forKey: .results)
    }

    private enum CodingKeys: String, CodingKey {
        case count, results
    }
}

struct RAWGGame: Sendable {
    let id: Int
    let name: String
    let released: String?
    let backgroundImage: String?
    let metacritic: Int?
    let playtime: Int?
    let genres: [RAWGGenre]?
    let platforms: [RAWGPlatformWrapper]?

    nonisolated func toiTunesSearchItem() -> iTunesSearchItem {
        let genreName = genres?.first?.name
        let rawgWebURL = "https://rawg.io/games/\(id)"
        let platformNames = platforms?.map { $0.platform.name } ?? []

        return iTunesSearchItem(
            trackId: id,
            collectionId: nil,
            artistId: nil,
            trackName: name,
            collectionName: nil,
            artistName: nil,
            artworkUrl30: nil,
            artworkUrl60: nil,
            artworkUrl100: backgroundImage,
            primaryGenreName: genreName,
            releaseDate: released,
            contentAdvisoryRating: nil,
            trackTimeMillis: nil,
            trackCount: nil,
            discCount: nil,
            trackViewUrl: rawgWebURL,
            collectionViewUrl: nil,
            previewUrl: nil,
            kind: "video-game",
            wrapperType: "track",
            collectionExplicitness: nil,
            trackExplicitness: nil,
            feedUrl: nil,
            description: nil,
            genres: nil,
            gamePlatforms: platformNames,
            metacriticScore: metacritic,
            playtimeHours: playtime
        )
    }
}

extension RAWGGame: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        released = try container.decodeIfPresent(String.self, forKey: .released)
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        metacritic = try container.decodeIfPresent(Int.self, forKey: .metacritic)
        playtime = try container.decodeIfPresent(Int.self, forKey: .playtime)
        genres = try container.decodeIfPresent([RAWGGenre].self, forKey: .genres)
        platforms = try container.decodeIfPresent([RAWGPlatformWrapper].self, forKey: .platforms)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, released, backgroundImage, metacritic, playtime, genres, platforms
    }
}

struct RAWGGenre: Sendable {
    let id: Int
    let name: String
}

extension RAWGGenre: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }
}

struct RAWGPlatformWrapper: Sendable {
    let platform: RAWGPlatformInfo
}

extension RAWGPlatformWrapper: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platform = try container.decode(RAWGPlatformInfo.self, forKey: .platform)
    }

    private enum CodingKeys: String, CodingKey {
        case platform
    }
}

struct RAWGPlatformInfo: Sendable {
    let id: Int
    let name: String
}

extension RAWGPlatformInfo: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }
}

// MARK: - Errors

enum RAWGSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from RAWG"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
