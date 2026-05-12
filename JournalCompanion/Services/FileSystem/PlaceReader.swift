//
//  PlaceReader.swift
//  JournalCompanion
//
//  Handles reading and parsing of place files from the vault.
//  Scans both the canonical (flat) location and the legacy `Places/` folder.
//

import Foundation

actor PlaceReader {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Load all places from the vault, deduped by filename.
    func loadPlaces() async throws -> [Place] {
        var fileURLs: [URL] = []

        // Canonical (flat) location — vault root by default.
        let canonicalURL = VaultPaths.url(for: .places, in: vaultURL)
        fileURLs.append(contentsOf: listMarkdownFiles(at: canonicalURL))

        // Legacy `Places/` folder, if it still exists and differs from canonical.
        if let legacyURL = VaultPaths.legacyURL(for: .places, in: vaultURL),
           legacyURL.standardizedFileURL != canonicalURL.standardizedFileURL,
           fileManager.fileExists(atPath: legacyURL.path) {
            fileURLs.append(contentsOf: listMarkdownFiles(at: legacyURL))
        }

        // Dedupe by filename (canonical wins because it was appended first).
        var seen = Set<String>()
        let uniqueURLs = fileURLs.filter { seen.insert($0.lastPathComponent).inserted }

        let places = try await withThrowingTaskGroup(of: Place?.self) { group in
            for fileURL in uniqueURLs {
                group.addTask { @Sendable in
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        return Place.parse(from: content, filename: fileURL.lastPathComponent)
                    } catch {
                        print("Error parsing place file \(fileURL.lastPathComponent): \(error)")
                        return nil
                    }
                }
            }

            var result: [Place] = []
            for try await place in group {
                if let place = place {
                    result.append(place)
                }
            }
            return result
        }

        return places.sorted { $0.name < $1.name }
    }

    /// List `.md` files directly within a directory (non-recursive).
    private func listMarkdownFiles(at directoryURL: URL) -> [URL] {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        let items = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return items.filter { $0.pathExtension == "md" }
    }
}
