//
//  PhotoEXIF.swift
//  JournalCompanion
//
//  EXIF metadata extracted from photos
//

import Foundation
import CoreLocation
import ImageIO

// MARK: - Photo EXIF Data Model

struct PhotoEXIF: Sendable {
    var location: CLLocationCoordinate2D?
    var timestamp: Date?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
    var aperture: Double?
    var exposureTime: Double?
    var iso: Int?

    /// Check if location data is available
    var hasLocation: Bool {
        location != nil
    }

    /// Check if timestamp is available
    var hasTimestamp: Bool {
        timestamp != nil
    }

    /// Check if any camera metadata is available
    var hasCameraInfo: Bool {
        cameraModel != nil || lensModel != nil || focalLength != nil
    }

    /// Format camera info for display
    var cameraInfoSummary: String? {
        var parts: [String] = []

        if let camera = cameraModel {
            parts.append(camera)
        }

        if let focal = focalLength {
            parts.append("\(Int(focal))mm")
        }

        if let aperture = aperture {
            parts.append("f/\(String(format: "%.1f", aperture))")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - EXIF Extraction

enum EXIFExtractor {

    /// Extract EXIF metadata from image data
    static func extractMetadata(from data: Data) -> PhotoEXIF? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        else {
            return nil
        }

        var exif = PhotoEXIF()

        // Extract GPS coordinates
        if let gpsInfo = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            exif.location = extractGPSCoordinates(from: gpsInfo)
        }

        // Extract timestamp from EXIF
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                exif.timestamp = parseEXIFDate(dateString)
            }

            // Extract camera settings
            exif.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
            exif.aperture = exifDict[kCGImagePropertyExifFNumber as String] as? Double
            exif.exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
            exif.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String

            if let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
               let iso = isoArray.first {
                exif.iso = iso
            }
        }

        // Extract camera model from TIFF dictionary
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            exif.cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        }

        return exif
    }

    /// Extract EXIF metadata from image URL
    static func extractMetadata(from url: URL) -> PhotoEXIF? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        else {
            return nil
        }

        var exif = PhotoEXIF()

        // Extract GPS coordinates
        if let gpsInfo = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            exif.location = extractGPSCoordinates(from: gpsInfo)
        }

        // Extract timestamp from EXIF
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                exif.timestamp = parseEXIFDate(dateString)
            }

            // Extract camera settings
            exif.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
            exif.aperture = exifDict[kCGImagePropertyExifFNumber as String] as? Double
            exif.exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
            exif.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String

            if let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
               let iso = isoArray.first {
                exif.iso = iso
            }
        }

        // Extract camera model from TIFF dictionary
        if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            exif.cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        }

        return exif
    }

    // MARK: - Private Helpers

    /// Extract GPS coordinates from GPS dictionary
    private static func extractGPSCoordinates(from gpsInfo: [String: Any]) -> CLLocationCoordinate2D? {
        guard let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
              let latRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let lonRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String
        else {
            return nil
        }

        let lat = latRef == "N" ? latitude : -latitude
        let lon = lonRef == "E" ? longitude : -longitude

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Parse EXIF date format: "YYYY:MM:DD HH:mm:ss"
    private static func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }
}
