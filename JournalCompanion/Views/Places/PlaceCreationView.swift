//
//  PlaceCreationView.swift
//  JournalCompanion
//
//  Place creation interface
//

import SwiftUI
import CoreLocation

struct PlaceCreationView: View {
    @StateObject var viewModel: PlaceCreationViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isNameFieldFocused: Bool
    @State private var showLocationSearch = false

    var body: some View {
        NavigationStack {
            Form {
                // Name Section (Required)
                Section {
                    TextField("Place Name", text: $viewModel.placeName)
                        .focused($isNameFieldFocused)
                } header: {
                    Text("Name")
                } footer: {
                    if viewModel.nameError != nil {
                        Text(viewModel.nameError!)
                            .foregroundStyle(.red)
                    }
                }

                // Location Section (MapKit Search)
                Section("Location") {
                    Button {
                        showLocationSearch = true
                    } label: {
                        HStack {
                            Image(systemName: viewModel.selectedLocationName != nil ? "checkmark.circle.fill" : "magnifyingglass")
                                .foregroundStyle(viewModel.selectedLocationName != nil ? .green : .blue)
                            if let locationName = viewModel.selectedLocationName {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(locationName)
                                        .foregroundStyle(.primary)
                                    if let address = viewModel.selectedAddress {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("Search for location")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(viewModel.selectedLocationName != nil ? "Change" : "")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }

                    // Show coordinates if available
                    if let coords = viewModel.selectedCoordinates {
                        LabeledContent("Coordinates") {
                            Text("\(String(format: "%.6f", coords.latitude)), \(String(format: "%.6f", coords.longitude))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Place Type Section
                Section("Type") {
                    Picker("Callout", selection: $viewModel.selectedCallout) {
                        ForEach(PlaceCreationViewModel.calloutTypes, id: \.self) { callout in
                            HStack {
                                Image(systemName: PlaceIcon.systemName(for: callout))
                                    .foregroundStyle(PlaceIcon.color(for: callout))
                                Text(callout.capitalized)
                            }
                            .tag(callout)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Notes Section (Optional)
                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createPlace()
                            if viewModel.creationSucceeded {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isCreating)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Only auto-focus name field if it's empty (not pre-populated)
                if viewModel.placeName.isEmpty {
                    isNameFieldFocused = true
                }
            }
            .onChange(of: viewModel.placeName) { _, _ in
                viewModel.validateName()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(
                    selectedLocationName: $viewModel.selectedLocationName,
                    selectedAddress: $viewModel.selectedAddress,
                    selectedCoordinates: $viewModel.selectedCoordinates
                )
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let templateManager = TemplateManager()
    let viewModel = PlaceCreationViewModel(vaultManager: vaultManager, locationService: locationService, templateManager: templateManager)
    PlaceCreationView(viewModel: viewModel)
}
