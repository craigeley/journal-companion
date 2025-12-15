//
//  PlaceDetailView.swift
//  JournalCompanion
//
//  Detail view for displaying comprehensive place information
//

import SwiftUI
import CoreLocation

struct PlaceDetailView: View {
    let place: Place
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Header Section with Icon
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: PlaceIcon.systemName(for: place.callout))
                                .font(.system(size: 60))
                                .foregroundStyle(PlaceIcon.color(for: place.callout))

                            Text(place.name)
                                .font(.title2)
                                .bold()

                            Text(place.callout.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Location Info
                if let address = place.address {
                    Section("Address") {
                        Text(address)
                    }
                }

                if let location = place.location {
                    Section("Coordinates") {
                        LabeledContent("Latitude", value: String(format: "%.6f", location.latitude))
                        LabeledContent("Longitude", value: String(format: "%.6f", location.longitude))
                    }
                }

                // Tags
                if !place.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(place.tags.filter { $0 != "place" }, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Aliases
                if !place.aliases.isEmpty {
                    Section("Aliases") {
                        ForEach(place.aliases, id: \.self) { alias in
                            Text(alias)
                        }
                    }
                }

                // URL
                if let urlString = place.url, let url = URL(string: urlString) {
                    Section("Link") {
                        Link(destination: url) {
                            HStack {
                                Text(urlString)
                                    .foregroundStyle(.blue)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // Metadata
                Section("Details") {
                    if let pin = place.pin {
                        LabeledContent("Pin", value: pin)
                    }
                    if let color = place.color {
                        LabeledContent("Color", value: color)
                    }
                }
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let samplePlace = Place(
        id: "sample-cafe",
        name: "Sample Cafe",
        location: nil,
        address: "123 Main Street, San Francisco, CA",
        tags: ["coffee", "wifi", "cafe"],
        callout: "cafe",
        pin: "mappin.circle.fill",
        color: "orange",
        url: "https://example.com",
        aliases: ["The Sample", "Sample Coffee Shop"],
        content: ""
    )
    PlaceDetailView(place: samplePlace)
}
