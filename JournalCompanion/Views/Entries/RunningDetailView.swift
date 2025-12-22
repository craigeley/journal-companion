//
//  RunningDetailView.swift
//  JournalCompanion
//
//  Displays running workout metrics and route map for running entries
//

import SwiftUI
import CoreLocation

@MainActor
struct RunningDetailView: View {
    let entry: Entry
    let vaultURL: URL

    @State private var mapImage: UIImage?
    @State private var routeCoordinates: [CLLocationCoordinate2D]?
    @State private var showInteractiveMap = false
    @State private var isLoadingImage = true
    @State private var imageLoadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Metrics section
            if hasAnyMetrics {
                metricsView
            } else {
                Text("No metrics available")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            // Map section
            if isLoadingImage {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if let coordinates = routeCoordinates {
                // Interactive map preview
                Button {
                    showInteractiveMap = true
                } label: {
                    WorkoutRouteMapView(coordinates: coordinates)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.blue)
                                .clipShape(Circle())
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            } else if let image = mapImage {
                mapImageView(image: image)
            } else if imageLoadError != nil {
                mapPlaceholder
            }
        }
        .sheet(isPresented: $showInteractiveMap) {
            if let coordinates = routeCoordinates {
                NavigationStack {
                    WorkoutRouteMapView(coordinates: coordinates)
                        .navigationTitle("Route")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showInteractiveMap = false
                                }
                            }
                        }
                }
            }
        }
        .task {
            await loadRouteData()
        }
    }

    // MARK: - Metrics View

    private var metricsView: some View {
        VStack(spacing: 12) {
            // Distance - prominent display
            if let distance = entry.distance {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text(formatDistance(distance))
                        .font(.title)
                        .fontWeight(.semibold)
                    Spacer()
                }
            }

            // Time and Pace
            HStack(spacing: 20) {
                if let time = entry.time {
                    metricRow(
                        icon: "timer",
                        label: "Time",
                        value: formatTime(time),
                        color: .blue
                    )
                }

                if let pace = entry.pace {
                    metricRow(
                        icon: "speedometer",
                        label: "Pace",
                        value: formatPace(pace),
                        color: .green
                    )
                }
            }

            // Cadence and Heart Rate
            HStack(spacing: 20) {
                if let cadence = entry.avgCadence {
                    metricRow(
                        icon: "metronome",
                        label: "Cadence",
                        value: formatCadence(cadence),
                        color: .purple
                    )
                }

                if let hr = entry.avgHeartRate {
                    metricRow(
                        icon: "heart.fill",
                        label: "Heart Rate",
                        value: formatHeartRate(hr),
                        color: .red
                    )
                }
            }

            // Power and Ground Contact Time
            HStack(spacing: 20) {
                if let power = entry.avgPower {
                    metricRow(
                        icon: "bolt.fill",
                        label: "Power",
                        value: formatPower(power),
                        color: .orange
                    )
                }

                if let gct = entry.avgStanceTime {
                    metricRow(
                        icon: "figure.run",
                        label: "Ground Contact",
                        value: formatGroundContactTime(gct),
                        color: .cyan
                    )
                }
            }

            // Step Length and Vertical Oscillation
            HStack(spacing: 20) {
                if let stepLength = entry.avgStepLength {
                    metricRow(
                        icon: "ruler",
                        label: "Step Length",
                        value: formatStepLength(stepLength),
                        color: .indigo
                    )
                }

                if let vo = entry.avgVerticalOscillation {
                    metricRow(
                        icon: "arrow.up.and.down",
                        label: "Vertical Osc.",
                        value: formatVerticalOscillation(vo),
                        color: .mint
                    )
                }
            }

            // Vertical Ratio
            if let vr = entry.avgVerticalRatio {
                HStack(spacing: 20) {
                    metricRow(
                        icon: "percent",
                        label: "Vertical Ratio",
                        value: formatVerticalRatio(vr),
                        color: .teal
                    )
                    Spacer()
                }
            }
        }
    }

    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }

    // MARK: - Map View

    private func mapImageView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }

    private var mapPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Map not available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var hasAnyMetrics: Bool {
        entry.distance != nil || entry.time != nil || entry.pace != nil ||
        entry.avgCadence != nil || entry.avgHeartRate != nil ||
        entry.avgPower != nil || entry.avgStanceTime != nil ||
        entry.avgStepLength != nil || entry.avgVerticalOscillation != nil ||
        entry.avgVerticalRatio != nil
    }

    private func formatDistance(_ distance: Double) -> String {
        String(format: "%.2f mi", distance)
    }

    private func formatTime(_ time: String) -> String {
        time
    }

    private func formatPace(_ pace: String) -> String {
        pace.contains("/mi") ? pace : "\(pace) /mi"
    }

    private func formatCadence(_ cadence: Int) -> String {
        "\(cadence) spm"
    }

    private func formatHeartRate(_ hr: Int) -> String {
        "\(hr) bpm"
    }

    private func formatPower(_ power: Int) -> String {
        "\(power) W"
    }

    private func formatGroundContactTime(_ gct: Double) -> String {
        String(format: "%.0f ms", gct)
    }

    private func formatStepLength(_ length: Double) -> String {
        String(format: "%.0f mm", length)
    }

    private func formatVerticalOscillation(_ vo: Double) -> String {
        String(format: "%.1f mm", vo)
    }

    private func formatVerticalRatio(_ vr: Double) -> String {
        String(format: "%.1f%%", vr)
    }

    private func loadRouteData() async {
        // Try to load GPX first
        if let gpxFilename = entry.routeFile {
            let gpxURL = vaultURL
                .appendingPathComponent("_attachments")
                .appendingPathComponent("routes")
                .appendingPathComponent(gpxFilename)

            if let coordinates = parseGPX(at: gpxURL), !coordinates.isEmpty {
                await MainActor.run {
                    routeCoordinates = coordinates
                    isLoadingImage = false
                }
                return
            }
        }

        // Fallback to static map image
        await loadMapImage()
    }

    private func loadMapImage() async {
        // Construct path to map image
        let mapPath = vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("maps")
            .appendingPathComponent("\(entry.id)-map.png")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: mapPath.path) else {
            await MainActor.run {
                isLoadingImage = false
                imageLoadError = "File not found"
            }
            return
        }

        // Load image
        if let image = UIImage(contentsOfFile: mapPath.path) {
            await MainActor.run {
                mapImage = image
                isLoadingImage = false
            }
        } else {
            await MainActor.run {
                isLoadingImage = false
                imageLoadError = "Failed to load image"
            }
        }
    }

    private func parseGPX(at url: URL) -> [CLLocationCoordinate2D]? {
        // Simple GPX parser
        guard FileManager.default.fileExists(atPath: url.path),
              let gpxString = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        var coordinates: [CLLocationCoordinate2D] = []

        // Parse <trkpt lat="..." lon="...">
        let pattern = #"<trkpt lat="([^"]+)" lon="([^"]+)">"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let matches = regex.matches(
            in: gpxString,
            range: NSRange(gpxString.startIndex..., in: gpxString)
        )

        for match in matches {
            if match.numberOfRanges == 3,
               let latRange = Range(match.range(at: 1), in: gpxString),
               let lonRange = Range(match.range(at: 2), in: gpxString),
               let lat = Double(gpxString[latRange]),
               let lon = Double(gpxString[lonRange]) {
                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }

        print("✓ Parsed \(coordinates.count) coordinates from GPX")
        return coordinates.isEmpty ? nil : coordinates
    }
}
