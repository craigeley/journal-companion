//
//  iTunesSearchService.swift
//  JournalCompanion
//
//  Network service for iTunes Search API
//

import Foundation

actor iTunesSearchService {
    private let baseURL = "https://itunes.apple.com/search"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Decode response outside of actor isolation to satisfy Swift 6 concurrency
    private nonisolated func decodeResponse(_ data: Data) throws -> iTunesSearchResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(iTunesSearchResponse.self, from: data)
    }

    /// Search iTunes for media
    /// - Parameters:
    ///   - term: Search query
    ///   - mediaType: Type of media to search for
    ///   - limit: Maximum number of results (default 25)
    /// - Returns: Array of search results
    func search(term: String, mediaType: MediaType, limit: Int = 25) async throws -> [iTunesSearchItem] {
        guard var components = URLComponents(string: baseURL) else {
            throw iTunesSearchError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: mediaType.iTunesMedia),
            URLQueryItem(name: "entity", value: mediaType.iTunesEntity),
            URLQueryItem(name: "country", value: "US"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            throw iTunesSearchError.invalidURL
        }

        print("🔍 iTunes Search: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw iTunesSearchError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ iTunes API returned status: \(httpResponse.statusCode)")
                throw iTunesSearchError.invalidResponse
            }

            let searchResponse = try decodeResponse(data)

            print("✓ iTunes returned \(searchResponse.resultCount) results")

            return searchResponse.results
        } catch let error as iTunesSearchError {
            throw error
        } catch let error as DecodingError {
            print("❌ iTunes decoding error: \(error)")
            throw iTunesSearchError.invalidResponse
        } catch {
            print("❌ iTunes network error: \(error)")
            throw iTunesSearchError.networkError(error)
        }
    }

    /// Lookup a specific item by iTunes ID
    /// - Parameters:
    ///   - id: iTunes ID
    ///   - mediaType: Type of media
    /// - Returns: The item if found
    func lookup(id: String, mediaType: MediaType) async throws -> iTunesSearchItem? {
        guard var components = URLComponents(string: "https://itunes.apple.com/lookup") else {
            throw iTunesSearchError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "entity", value: mediaType.iTunesEntity),
            URLQueryItem(name: "country", value: "US")
        ]

        guard let url = components.url else {
            throw iTunesSearchError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw iTunesSearchError.invalidResponse
            }

            let searchResponse = try decodeResponse(data)

            return searchResponse.results.first
        } catch let error as iTunesSearchError {
            throw error
        } catch {
            throw iTunesSearchError.networkError(error)
        }
    }
}
