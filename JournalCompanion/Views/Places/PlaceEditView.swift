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

                    if let address = viewModel.address {
                        LabeledContent("Address", value: address)
                    }

                    LabeledContent("Type", value: viewModel.callout.capitalized)

                    if let location = viewModel.location {
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
                if !viewModel.tags.isEmpty {
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
                if !viewModel.aliases.isEmpty {
                    Section("Aliases") {
                        ForEach(viewModel.aliases, id: \.self) { alias in
                            Text(alias)
                        }
                    }
                }

                // URL Section
                if let urlString = viewModel.url, let url = URL(string: urlString) {
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
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
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
    let viewModel = PlaceEditViewModel(place: samplePlace, vaultManager: vaultManager)
    return PlaceEditView(viewModel: viewModel)
}
