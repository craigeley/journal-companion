//
//  PlaceEditView.swift
//  JournalCompanion
//
//  Edit screen for places
//

import SwiftUI
import CoreLocation

struct PlaceEditView: View {
    @StateObject var viewModel: PlaceEditViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var templateManager: TemplateManager
    @State private var showAddAlias = false
    @State private var newAlias = ""

    var body: some View {
        NavigationStack {
            Form {
                // Body content at top (primary edit area)
                Section("Notes") {
                    TextEditor(text: $viewModel.bodyText)
                        .frame(minHeight: 200)
                        .font(.body)
                }

                // Read-only metadata (excluding pin and color)
                Section("Details") {
                    LabeledContent("Name", value: viewModel.name)

                    if templateManager.placeTemplate.isEnabled("addr"),
                       let address = viewModel.address {
                        LabeledContent("Address", value: address)
                    }

                    LabeledContent("Type", value: viewModel.callout.capitalized)

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

                // Tags Section
                if templateManager.placeTemplate.isEnabled("tags") && !viewModel.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.tags.filter { $0 != "place" }, id: \.self) { tag in
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

                // URL Section
                if templateManager.placeTemplate.isEnabled("url"),
                   let urlString = viewModel.url,
                   let url = URL(string: urlString) {
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
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.saveChanges() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Save Error", isPresented: .constant(viewModel.saveError != nil)) {
                Button("OK") {
                    viewModel.saveError = nil
                }
            } message: {
                if let error = viewModel.saveError {
                    Text(error)
                }
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
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let templateManager = TemplateManager()
    let samplePlace = Place(
        id: "sample-cafe",
        name: "Sample Cafe",
        location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        address: "123 Main Street, San Francisco, CA",
        tags: ["coffee", "wifi", "cafe"],
        callout: "cafe",
        pin: "mappin.circle.fill",
        color: "rgb(205,145,95)",
        url: "https://example.com",
        aliases: ["The Sample", "Sample Coffee Shop"],
        content: "This is a great cafe with excellent coffee and WiFi."
    )
    let viewModel = PlaceEditViewModel(place: samplePlace, vaultManager: vaultManager, templateManager: templateManager)
    PlaceEditView(viewModel: viewModel)
}
