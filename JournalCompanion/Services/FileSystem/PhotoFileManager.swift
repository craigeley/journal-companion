//
//  PhotoFileManager.swift
//  JournalCompanion
//
//  Actor-based photo file management for vault storage
//

import Foundation

// MARK: - Photo File Manager

actor PhotoFileManager {
    private let vaultURL: URL
    private let fileManager = FileManager.default

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    // MARK: - Directory Management

    /// Create _attachments/photos directory if needed
    func createPhotosDirectory() async throws -> URL {
        let photosDir = photosDirectory()

        if !fileManager.fileExists(atPath: photosDir.path) {
            try fileManager.createDirectory(
                at: photosDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✓ Created photos directory: \(photosDir.lastPathComponent)")
        }

        return photosDir
    }

    /// Ensure root _attachments directory exists
    func ensureAttachmentsDirectory() async throws {
        let attachmentsDir = vaultURL.appendingPathComponent("_attachments")

        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            try fileManager.createDirectory(
                at: attachmentsDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✓ Created _attachments directory")
        }
    }

    // MARK: - Photo File Operations

    /// Write photo file from data to vault
    /// Returns the filename for YAML/markdown storage
    func writePhoto(
        data: Data,
        for entry: Entry,
        fileExtension: String
    ) async throws -> String {
        // Ensure directory exists
        let photosDir = try await createPhotosDirectory()

        // Generate filename: YYYYMMDDHHmm.ext
        let filename = "\(entry.filename).\(fileExtension)"
        let destinationURL = photosDir.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw PhotoFileError.fileAlreadyExists(filename)
        }

        // Write data to vault
        try data.write(to: destinationURL)

        print("✓ Wrote photo file: \(filename)")
        return filename
    }

    /// Copy photo file from temp URL to vault
    /// Returns the filename for YAML/markdown storage
    func writePhoto(
        from sourceURL: URL,
        for entry: Entry,
        fileExtension: String
    ) async throws -> String {
        // Ensure directory exists
        let photosDir = try await createPhotosDirectory()

        // Generate filename: YYYYMMDDHHmm.ext
        let filename = "\(entry.filename).\(fileExtension)"
        let destinationURL = photosDir.appendingPathComponent(filename)

        // Check if file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw PhotoFileError.fileAlreadyExists(filename)
        }

        // Copy file to vault
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        print("✓ Copied photo file: \(filename)")
        return filename
    }

    /// Delete photo file from vault
    func deletePhoto(filename: String) async throws {
        let photosDir = photosDirectory()
        let fileURL = photosDir.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PhotoFileError.fileNotFound(filename)
        }

        try fileManager.removeItem(at: fileURL)
        print("✓ Deleted photo file: \(filename)")
    }

    /// Get photo file URL for display
    func photoURL(filename: String) async throws -> URL {
        let photosDir = photosDirectory()
        let fileURL = photosDir.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PhotoFileError.fileNotFound(filename)
        }

        return fileURL
    }

    /// Get file size for photo file
    func fileSize(filename: String) async throws -> Int64 {
        let fileURL = try await photoURL(filename: filename)
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Check if photo file exists
    func fileExists(filename: String) async -> Bool {
        let photosDir = photosDirectory()
        let fileURL = photosDir.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Clean up temporary photo files
    func cleanupTempFiles(_ urls: [URL]) async {
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
        if !urls.isEmpty {
            print("✓ Cleaned up \(urls.count) temporary photo file(s)")
        }
    }

    // MARK: - Private Helpers

    /// Get photos directory path
    /// Format: _attachments/photos/
    private func photosDirectory() -> URL {
        vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("photos")
    }
}

// MARK: - Errors

enum PhotoFileError: LocalizedError {
    case fileAlreadyExists(String)
    case fileNotFound(String)
    case directoryCreationFailed
    case copyFailed(Error)
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let filename):
            return "Photo file already exists: \(filename)"
        case .fileNotFound(let filename):
            return "Photo file not found: \(filename)"
        case .directoryCreationFailed:
            return "Failed to create photos directory."
        case .copyFailed(let error):
            return "Failed to copy photo file: \(error.localizedDescription)"
        case .invalidImageData:
            return "Invalid image data."
        }
    }
}
