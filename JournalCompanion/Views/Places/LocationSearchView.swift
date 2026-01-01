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
    @State private var isSearchPresented = true  // Auto-focus search on appear
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    // Bindings to pass results back
    @Binding var selectedLocationName: String?
    @Binding var selectedAddress: String?
    @Binding var selectedCoordinates: CLLocationCoordinate2D?
    @Binding var selectedURL: String?
    @Binding var selectedPOICategory: MKPointOfInterestCategory?

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
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search for a place")
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
            .alert("Location Search Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred while searching for the location.")
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
                // Use completion subtitle for address (already formatted by MapKit)
                selectedAddress = !completion.subtitle.isEmpty ? completion.subtitle : nil
                selectedCoordinates = mapItem.location.coordinate
                // Extract URL if available (common for POIs like restaurants, businesses)
                selectedURL = mapItem.url?.absoluteString
                // Extract POI category for automatic callout type detection
                selectedPOICategory = mapItem.pointOfInterestCategory

                dismiss()
            } else {
                // No results found
                errorMessage = "No location details found for '\(completion.title)'. Please try a different search."
                showErrorAlert = true
            }
        } catch {
            // Network or MapKit error
            errorMessage = "Could not fetch location details: \(error.localizedDescription)"
            showErrorAlert = true
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
        selectedCoordinates: .constant(nil),
        selectedURL: .constant(nil),
        selectedPOICategory: .constant(nil)
    )
}
