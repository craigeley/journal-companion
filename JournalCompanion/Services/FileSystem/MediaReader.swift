//
//  MediaReader.swift
//  JournalCompanion
//
//  Handles reading and parsing of media files from vault
//

import Foundation

actor MediaReader {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Load all media from vault
    func loadMedia() async throws -> [Media] {
        let mediaURL = vaultURL.appendingPathComponent("Media")

        guard fileManager.fileExists(atPath: mediaURL.path) else {
            print("⚠️ Media directory not found")
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: mediaURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let media = try await withThrowingTaskGroup(of: Media?.self) { group in
            for fileURL in files where fileURL.pathExtension == "md" {
                group.addTask { @Sendable in
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let filename = fileURL.lastPathComponent
                        return Media.parse(from: content, filename: filename)
                    } catch {
                        print("Error parsing media file \(fileURL.lastPathComponent): \(error)")
                        return nil
                    }
                }
            }

            var result: [Media] = []
            for try await mediaItem in group {
                if let mediaItem = mediaItem {
                    result.append(mediaItem)
                }
            }
            return result
        }

        print("✓ Loaded \(media.count) media items")
        return media.sorted { $0.title < $1.title }
    }
}
