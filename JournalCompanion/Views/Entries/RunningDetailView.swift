//
//  RunningDetailView.swift
//  JournalCompanion
//
//  Displays running workout metrics and route map for running entries
//

import SwiftUI

@MainActor
struct RunningDetailView: View {
    let entry: Entry
    let vaultURL: URL

    @State private var mapImage: UIImage?
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
            } else if let image = mapImage {
                mapImageView(image: image)
            } else if imageLoadError != nil {
                mapPlaceholder
            }
        }
        .task {
            await loadMapImage()
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
        entry.avgCadence != nil || entry.avgHeartRate != nil
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
}
