//
//  LocationSearchView.swift
//  JournalCompanion
//
//  MapKit location search interface
//

import SwiftUI
import MapKit
import Combine

struct LocationSearchView: View {
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    // Bindings to pass results back
    @Binding var selectedLocationName: String?
    @Binding var selectedAddress: String?
    @Binding var selectedCoordinates: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            List {
                if searchCompleter.completions.isEmpty && searchText.isEmpty {
                    ContentUnavailableView {
                        Label("Search for a Location", systemImage: "magnifyingglass")
                    } description: {
                        Text("Start typing to search for places")
                    }
                } else if searchCompleter.completions.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No locations found for '\(searchText)'")
                    }
                } else {
                    ForEach(searchCompleter.completions) { completion in
                        Button {
                            Task {
                                await selectLocation(completion)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search for a place")
            .navigationTitle("Location Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                searchCompleter.updateQuery(newValue)
            }
        }
    }

    /// Select a location from search results and fetch details
    private func selectLocation(_ completion: MKLocalSearchCompletion) async {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        do {
            let response = try await search.start()

            if let mapItem = response.mapItems.first {
                // Extract location details
                selectedLocationName = mapItem.name
                // Note: Using placemark for now as MKAddress API is still evolving in iOS 26.0
                selectedAddress = mapItem.placemark.title
                selectedCoordinates = mapItem.location.coordinate

                dismiss()
            }
        } catch {
            print("Error fetching location details: \(error)")
        }
    }
}

// MARK: - Location Search Completer

@MainActor
class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error)")
    }
}

// Make MKLocalSearchCompletion Identifiable for ForEach
extension MKLocalSearchCompletion: @retroactive Identifiable {
    public var id: String {
        title + subtitle
    }
}

// MARK: - Preview
#Preview {
    LocationSearchView(
        selectedLocationName: .constant(nil),
        selectedAddress: .constant(nil),
        selectedCoordinates: .constant(nil)
    )
}
