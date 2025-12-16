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

    /// Load all people from vault
    func loadPeople() async throws -> [Person] {
        let peopleURL = vaultURL.appendingPathComponent("People")

        guard fileManager.fileExists(atPath: peopleURL.path) else {
            print("⚠️ People directory not found")
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: peopleURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let people = try await withThrowingTaskGroup(of: Person?.self) { group in
            for fileURL in files where fileURL.pathExtension == "md" {
                group.addTask { @Sendable in
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let filename = fileURL.lastPathComponent
                        return Person.parse(from: content, filename: filename)
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
}
