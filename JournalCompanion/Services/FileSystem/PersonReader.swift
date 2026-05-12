//
//  PersonReader.swift
//  JournalCompanion
//
//  Handles reading and parsing of person files from vault
//

import Foundation

actor PersonReader {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Load all people from vault, scanning both the canonical (flat) location
    /// and the legacy `People/` folder for pre-migration files.
    func loadPeople() async throws -> [Person] {
        var fileURLs: [URL] = []

        let canonicalURL = VaultPaths.url(for: .people, in: vaultURL)
        fileURLs.append(contentsOf: listMarkdownFiles(at: canonicalURL))

        if let legacyURL = VaultPaths.legacyURL(for: .people, in: vaultURL),
           legacyURL.standardizedFileURL != canonicalURL.standardizedFileURL,
           fileManager.fileExists(atPath: legacyURL.path) {
            fileURLs.append(contentsOf: listMarkdownFiles(at: legacyURL))
        }

        // Dedupe by filename
        var seen = Set<String>()
        let uniqueURLs = fileURLs.filter { seen.insert($0.lastPathComponent).inserted }

        let people = try await withThrowingTaskGroup(of: Person?.self) { group in
            for fileURL in uniqueURLs {
                group.addTask { @Sendable in
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        return Person.parse(from: content, filename: fileURL.lastPathComponent)
                    } catch {
                        print("Error parsing person file \(fileURL.lastPathComponent): \(error)")
                        return nil
                    }
                }
            }

            var result: [Person] = []
            for try await person in group {
                if let person = person {
                    result.append(person)
                }
            }
            return result
        }

        print("✓ Loaded \(people.count) people")
        return people.sorted { $0.name < $1.name }
    }

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
