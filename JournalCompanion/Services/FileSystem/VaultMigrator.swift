//
//  VaultMigrator.swift
//  JournalCompanion
//
//  One-shot migration tool that flattens the legacy vault layout
//  (Entries/YYYY/MM-Month/DD, Places/, People/, Media/) into the
//  vault root. Binary attachments under `_attachments/` are left alone.
//
//  Idempotent: re-runs over an already-flat vault do nothing.
//  Conservative on collisions: files at root with the same name are
//  preserved; the legacy copy is skipped and reported.
//

import Foundation

/// Result of a single migration run.
nonisolated struct VaultMigrationReport: Sendable {
    var movedFiles: [String] = []
    var skippedCollisions: [String] = []
    var emptiedFolders: [String] = []
    var errors: [String] = []

    var summary: String {
        var lines: [String] = []
        lines.append("Moved \(movedFiles.count) file\(movedFiles.count == 1 ? "" : "s") to vault root.")
        if !skippedCollisions.isEmpty {
            lines.append("Skipped \(skippedCollisions.count) file\(skippedCollisions.count == 1 ? "" : "s") (name conflicts at root).")
        }
        if !emptiedFolders.isEmpty {
            lines.append("Removed \(emptiedFolders.count) empty legacy folder\(emptiedFolders.count == 1 ? "" : "s").")
        }
        if !errors.isEmpty {
            lines.append("Encountered \(errors.count) error\(errors.count == 1 ? "" : "s").")
        }
        return lines.joined(separator: "\n")
    }
}

actor VaultMigrator {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    /// Migrate the vault to a flat layout.
    /// Moves all `.md` files out of legacy category folders into the vault root.
    /// Leaves `_attachments/` untouched.
    func migrate() async -> VaultMigrationReport {
        var report = VaultMigrationReport()

        // Order matters only for readability — each category is independent.
        let categories: [VaultCategory] = [.entries, .places, .people, .media]
        for category in categories {
            migrateCategory(category, report: &report)
        }

        return report
    }

    private func migrateCategory(_ category: VaultCategory, report: inout VaultMigrationReport) {
        guard let legacyRoot = VaultPaths.legacyURL(for: category, in: vaultURL),
              fileManager.fileExists(atPath: legacyRoot.path) else {
            return
        }

        // Don't migrate if canonical == legacy (would be a no-op move).
        let canonicalRoot = VaultPaths.url(for: category, in: vaultURL)
        if canonicalRoot.standardizedFileURL == legacyRoot.standardizedFileURL {
            return
        }

        // Walk all `.md` files recursively (handles Entries/YYYY/MM-Month/DD nesting).
        guard let enumerator = fileManager.enumerator(
            at: legacyRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let sourceURL as URL in enumerator where sourceURL.pathExtension == "md" {
            let filename = sourceURL.lastPathComponent
            let destinationURL = canonicalRoot.appendingPathComponent(filename)

            // Skip if a file with this name already exists at the canonical location.
            if fileManager.fileExists(atPath: destinationURL.path) {
                let relativeSource = sourceURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
                report.skippedCollisions.append(relativeSource)
                continue
            }

            do {
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                report.movedFiles.append(filename)
            } catch {
                let relativeSource = sourceURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
                report.errors.append("Failed to move \(relativeSource): \(error.localizedDescription)")
            }
        }

        // Remove now-empty legacy directories (depth-first).
        removeEmptyDirectoriesDepthFirst(at: legacyRoot, report: &report)
    }

    /// Recursively delete empty directories. Leaves non-empty directories in place.
    private func removeEmptyDirectoriesDepthFirst(at directoryURL: URL, report: inout VaultMigrationReport) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for item in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                removeEmptyDirectoriesDepthFirst(at: item, report: &report)
            }
        }

        // Re-check contents after recursion — child dirs may have been removed.
        let remaining = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        if remaining.isEmpty {
            do {
                try fileManager.removeItem(at: directoryURL)
                let relative = directoryURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
                report.emptiedFolders.append(relative)
            } catch {
                let relative = directoryURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
                report.errors.append("Failed to remove empty folder \(relative): \(error.localizedDescription)")
            }
        }
    }
}
