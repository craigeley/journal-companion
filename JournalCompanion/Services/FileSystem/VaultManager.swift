//
//  VaultManager.swift
//  JournalCompanion
//
//  Manages access to the Obsidian vault in iCloud Drive
//

import Foundation
import Combine

class VaultManager: ObservableObject {
    @Published var vaultURL: URL?
    @Published var isVaultAccessible = false
    @Published var places: [Place] = []
    @Published var isLoadingPlaces = false
    @Published var people: [Person] = []
    @Published var isLoadingPeople = false
    @Published var entries: [Entry] = []
    @Published var isLoadingEntries = false

    private let userDefaults = UserDefaults.standard
    private static let vaultBookmarkKey = "vaultSecurityBookmark"
    private static let vaultPathKey = "vaultPath"

    init() {
        // Try to restore vault from saved bookmark
        Task {
            do {
                _ = try await restoreVault()
                _ = try await loadPlaces()
                _ = try await loadPeople()
                // Note: Entries are loaded by EntryListView.task to avoid duplicate loads
            } catch {
                // No saved vault or failed to restore - user will need to select one
                print("No saved vault found")
            }
        }
    }

    /// Set vault URL from user selection (via document picker)
    func setVault(url: URL) async throws {
        print("DEBUG: Setting vault to: \(url.path)")

        // Verify the URL is accessible and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw VaultError.vaultNotFound(searchPath: url.path)
        }

        // Create security-scoped bookmark for persistent access
        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            userDefaults.set(bookmarkData, forKey: Self.vaultBookmarkKey)
            userDefaults.set(url.path, forKey: Self.vaultPathKey)
            print("DEBUG: Saved security-scoped bookmark")
        } catch {
            print("Failed to create bookmark: \(error)")
            throw VaultError.fileWriteError("Failed to save vault bookmark")
        }

        await MainActor.run {
            self.vaultURL = url
            self.isVaultAccessible = true
        }

        print("DEBUG: Vault configured successfully")
    }

    /// Restore vault from saved bookmark
    func restoreVault() async throws -> URL {
        guard let bookmarkData = userDefaults.data(forKey: Self.vaultBookmarkKey) else {
            throw VaultError.noVault
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else {
            throw VaultError.noVault
        }

        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw VaultError.noVault
        }

        await MainActor.run {
            self.vaultURL = url
            self.isVaultAccessible = true
        }

        return url
    }

    /// Check if saved vault URL is still accessible
    func checkVaultAccessibility() async {
        guard let url = vaultURL else {
            await MainActor.run {
                self.isVaultAccessible = false
            }
            return
        }

        let accessible = FileManager.default.fileExists(atPath: url.path)
        await MainActor.run {
            self.isVaultAccessible = accessible
        }
    }

    /// Load all places from the vault
    func loadPlaces() async throws -> [Place] {
        guard let vaultURL = vaultURL else {
            throw VaultError.noVault
        }

        await MainActor.run {
            self.isLoadingPlaces = true
        }

        let placesURL = vaultURL.appendingPathComponent("Places")

        guard FileManager.default.fileExists(atPath: placesURL.path) else {
            await MainActor.run {
                self.isLoadingPlaces = false
            }
            return []
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: placesURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let places = try await withThrowingTaskGroup(of: Place?.self) { group in
            for fileURL in files where fileURL.pathExtension == "md" {
                group.addTask { @Sendable in
                    do {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let filename = fileURL.lastPathComponent
                        return Place.parse(from: content, filename: filename)
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

        await MainActor.run {
            self.places = places.sorted { $0.name < $1.name }
            self.isLoadingPlaces = false
        }

        return places
    }

    /// Load all people from the vault
    func loadPeople() async throws -> [Person] {
        guard let vaultURL = vaultURL else {
            throw VaultError.noVault
        }

        await MainActor.run {
            self.isLoadingPeople = true
        }

        let reader = PersonReader(vaultURL: vaultURL)
        let people = try await reader.loadPeople()

        await MainActor.run {
            self.people = people
            self.isLoadingPeople = false
        }

        return people
    }

    /// Load entries from the vault
    func loadEntries(limit: Int = 100) async throws -> [Entry] {
        guard let vaultURL = vaultURL else {
            throw VaultError.noVault
        }

        await MainActor.run {
            self.isLoadingEntries = true
        }

        let reader = EntryReader(vaultURL: vaultURL)
        let entries = try await reader.loadEntries(limit: limit)

        await MainActor.run {
            self.entries = entries
            self.isLoadingEntries = false
        }

        return entries
    }

    /// Get URL for a specific directory in the vault
    func getDirectoryURL(_ path: String) -> URL? {
        guard let vaultURL = vaultURL else { return nil }
        return vaultURL.appendingPathComponent(path)
    }

    /// Clear saved vault settings
    func clearVault() {
        userDefaults.removeObject(forKey: Self.vaultBookmarkKey)
        userDefaults.removeObject(forKey: Self.vaultPathKey)
        vaultURL = nil
        isVaultAccessible = false
        places = []
        people = []
        entries = []
    }
}

// MARK: - Errors
enum VaultError: LocalizedError {
    case iCloudNotAvailable
    case vaultNotFound(searchPath: String)
    case noVault
    case fileWriteError(String)
    case fileReadError(String)

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive is not available. Please enable iCloud Drive in Settings."
        case .vaultNotFound(let path):
            return "Vault not found at \(path). Please ensure your obsidian-journal vault is in iCloud Drive."
        case .noVault:
            return "No vault configured. Please select your vault location."
        case .fileWriteError(let msg):
            return "File write error: \(msg)"
        case .fileReadError(let msg):
            return "File read error: \(msg)"
        }
    }
}
