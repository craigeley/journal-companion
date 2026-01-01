//
//  PlaceEditView.swift
//  JournalCompanion
//
//  Unified view for creating and editing places
//

import SwiftUI
import CoreLocation

struct PlaceEditView: View {
    @StateObject var viewModel: PlaceEditViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var templateManager: TemplateManager
    @FocusState private var isNameFieldFocused: Bool
    @State private var showLocationSearch = false
    @State private var showAddAlias = false
    @State private var newAlias = ""
    @State private var showAddTag = false
    @State private var newTag = ""

    var body: some View {
        NavigationStack {
            Form {
                // CREATION MODE: Name Section (Required)
                if viewModel.isCreating {
                    Section {
                        TextField("Place Name", text: $viewModel.placeName)
                            .focused($isNameFieldFocused)
                    } header: {
                        Text("Name")
                    } footer: {
                        if let error = viewModel.nameError {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // CREATION MODE: Location Search
                if viewModel.isCreating {
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
                }

                // BOTH MODES: Callout Type (NOW EDITABLE!)
                Section("Type") {
                    Picker("Place Type", selection: $viewModel.callout) {
                        ForEach(PlaceEditViewModel.calloutTypes, id: \.self) { callout in
                            HStack {
                                Image(systemName: PlaceIcon.systemName(for: callout))
                                    .foregroundStyle(PlaceIcon.color(for: callout))
                                Text(callout.rawValue.capitalized)
                            }
                            .tag(callout)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // BOTH MODES: Notes
                Section("Notes") {
                    TextEditor(text: $viewModel.bodyText)
                        .frame(minHeight: 120)
                        .font(.body)
                }

                // EDIT MODE: Read-only metadata
                if !viewModel.isCreating {
                    Section("Details") {
                        LabeledContent("Name", value: viewModel.name)

                        if templateManager.placeTemplate.isEnabled("addr"),
                           let address = viewModel.address {
                            LabeledContent("Address", value: address)
                        }

                        if templateManager.placeTemplate.isEnabled("location"),
                           let location = viewModel.location {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude))")
                                    .font(.body)
                            }
                        }
                    }
                }

                // Tags Section
                if templateManager.placeTemplate.isEnabled("tags") {
                    Section("Tags") {
                        ForEach(viewModel.tags.indices, id: \.self) { index in
                            HStack {
                                Text(viewModel.tags[index])
                                Spacer()
                                Button(action: {
                                    viewModel.tags.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        Button("Add Tag") {
                            showAddTag = true
                        }
                    }
                }

                // Aliases Section
                if templateManager.placeTemplate.isEnabled("aliases") {
                    Section("Aliases") {
                        ForEach(viewModel.aliases.indices, id: \.self) { index in
                            HStack {
                                Text(viewModel.aliases[index])
                                Spacer()
                                Button(action: {
                                    viewModel.aliases.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        Button("Add Alias") {
                            showAddAlias = true
                        }
                    }
                }

                // URL Section (BOTH MODES: Now editable!)
                if templateManager.placeTemplate.isEnabled("url") {
                    Section("Website URL") {
                        TextField("https://example.com", text: $viewModel.url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                }
            }
            .navigationTitle(viewModel.isCreating ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(viewModel.isCreating ? "Create" : "Save")
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .onAppear {
                // Only auto-focus name field if creating and name is empty
                if viewModel.isCreating && viewModel.placeName.isEmpty {
                    isNameFieldFocused = true
                }
            }
            .onChange(of: viewModel.placeName) { _, _ in
                viewModel.validateName()
            }
            .onChange(of: viewModel.selectedURL) { _, newURL in
                // Auto-populate URL field when location with URL is selected
                if let urlString = newURL, !urlString.isEmpty {
                    viewModel.url = urlString
                }
            }
            .alert("Error", isPresented: .constant(viewModel.saveError != nil)) {
                Button("OK") {
                    viewModel.saveError = nil
                }
            } message: {
                if let error = viewModel.saveError {
                    Text(error)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(
                    selectedLocationName: $viewModel.selectedLocationName,
                    selectedAddress: $viewModel.selectedAddress,
                    selectedCoordinates: $viewModel.selectedCoordinates,
                    selectedURL: $viewModel.selectedURL,
                    selectedPOICategory: $viewModel.selectedPOICategory
                )
            }
            .alert("Add Alias", isPresented: $showAddAlias) {
                TextField("Alias", text: $newAlias)
                Button("Add") {
                    let trimmed = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !viewModel.aliases.contains(trimmed) {
                        viewModel.aliases.append(trimmed)
                    }
                    newAlias = ""
                }
                Button("Cancel", role: .cancel) {
                    newAlias = ""
                }
            } message: {
                Text("Enter an alternative name for this place")
            }
            .alert("Add Tag", isPresented: $showAddTag) {
                TextField("Tag", text: $newTag)
                Button("Add") {
                    let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !viewModel.tags.contains(trimmed) {
                        viewModel.tags.append(trimmed)
                    }
                    newTag = ""
                }
                Button("Cancel", role: .cancel) {
                    newTag = ""
                }
            } message: {
                Text("Enter a tag for this place")
            }
        }
    }
}

// MARK: - Preview
#Preview("Edit Mode") {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let templateManager = TemplateManager()
    let samplePlace = Place(
        id: "sample-cafe",
        name: "Sample Cafe",
        location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        address: "123 Main Street, San Francisco, CA",
        tags: ["coffee", "wifi", "cafe"],
        callout: .cafe,
        pin: "mappin.circle.fill",
        color: "rgb(205,145,95)",
        url: "https://example.com",
        aliases: ["The Sample", "Sample Coffee Shop"],
        content: "This is a great cafe with excellent coffee and WiFi."
    )
    let viewModel = PlaceEditViewModel(
        place: samplePlace,
        vaultManager: vaultManager,
        locationService: locationService,
        templateManager: templateManager
    )
    PlaceEditView(viewModel: viewModel)
        .environmentObject(templateManager)
}

#Preview("Create Mode") {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let templateManager = TemplateManager()
    let viewModel = PlaceEditViewModel(
        place: nil,  // nil = creation mode
        vaultManager: vaultManager,
        locationService: locationService,
        templateManager: templateManager
    )
    PlaceEditView(viewModel: viewModel)
        .environmentObject(templateManager)
}
