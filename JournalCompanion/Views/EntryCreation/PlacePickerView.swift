//
//  PlacePickerView.swift
//  JournalCompanion
//
//  Place selection interface
//

import SwiftUI
import CoreLocation

struct PlacePickerView: View {
    let places: [Place]
    let currentLocation: CLLocation?
    @Binding var selectedPlace: Place?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var nearbyPlaces: [PlaceWithDistance] = []
    @State private var placeMatcher = PlaceMatcher()

    var filteredPlaces: [Place] {
        if searchText.isEmpty {
            return places
        }
        return places.filter { place in
            place.name.localizedCaseInsensitiveContains(searchText) ||
            place.aliases.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Nearby Places Section (only show when we have location and it's not searching)
                if !nearbyPlaces.isEmpty && searchText.isEmpty {
                    Section("Nearby") {
                        ForEach(nearbyPlaces) { placeWithDistance in
                            PlaceRowWithDistance(placeWithDistance: placeWithDistance)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPlace = placeWithDistance.place
                                    dismiss()
                                }
                        }
                    }
                }

                // All Places or Filtered Places
                if filteredPlaces.isEmpty {
                    ContentUnavailableView {
                        Label("No Places Found", systemImage: "mappin.slash")
                    } description: {
                        Text("Try adjusting your search or create a new place")
                    }
                } else {
                    Section(searchText.isEmpty ? "All Places" : "Search Results") {
                        ForEach(filteredPlaces) { place in
                            PlaceRow(place: place)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedPlace = place
                                    dismiss()
                                }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search places")
            .navigationTitle("Select Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                // Calculate nearby places when view appears
                if let location = currentLocation {
                    nearbyPlaces = placeMatcher.findNearbyPlaces(from: location, in: places)
                    print("Found \(nearbyPlaces.count) nearby places")
                }
            }
        }
    }
}

// MARK: - Place Row
struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack {
            // Icon
            Image(systemName: PlaceIcon.systemName(for: place.callout))
                .foregroundStyle(PlaceIcon.color(for: place.callout))
                .frame(width: 32)

            // Place info
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.body)

                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !place.tags.isEmpty {
                    Text(place.tags.filter { $0 != "place" }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Place Row With Distance
struct PlaceRowWithDistance: View {
    let placeWithDistance: PlaceWithDistance

    var body: some View {
        HStack {
            // Icon
            Image(systemName: PlaceIcon.systemName(for: placeWithDistance.place.callout))
                .foregroundStyle(PlaceIcon.color(for: placeWithDistance.place.callout))
                .frame(width: 32)

            // Place info
            VStack(alignment: .leading, spacing: 2) {
                Text(placeWithDistance.place.name)
                    .font(.body)

                if let address = placeWithDistance.place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Distance badge
            Text(placeWithDistance.distanceFormatted)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    PlacePickerView(
        places: [
            Place(id: "test", name: "Test Place", location: nil, address: "123 Main St",
                  tags: ["place", "cafe"], callout: "cafe", pin: nil, color: nil,
                  url: nil, aliases: [], content: "")
        ],
        currentLocation: nil,
        selectedPlace: .constant(nil)
    )
}
