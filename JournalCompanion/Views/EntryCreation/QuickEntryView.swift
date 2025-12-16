//
//  QuickEntryView.swift
//  JournalCompanion
//
//  Quick entry creation interface
//

import SwiftUI
import JournalingSuggestions

struct QuickEntryView: View {
    @StateObject var viewModel: QuickEntryViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var showPlacePicker = false

    var body: some View {
        NavigationStack {
            Form {
                // Location Section
                Section("Location") {
                    Button {
                        showPlacePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.blue)
                            if let place = viewModel.selectedPlace {
                                Text(place.name)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Select Place")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                }

                // Suggestions Section
                Section {
                    Button {
                        viewModel.requestJournalingSuggestions()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("Get Suggestions")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }
                } footer: {
                    Text("See AI-powered suggestions from your day: photos, workouts, places, and more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Entry Section
                Section("Entry") {
                    TextEditor(text: $viewModel.entryText)
                        .frame(minHeight: 120)
                        .focused($isTextFieldFocused)
                }

                // Weather Section
                if let weather = viewModel.weatherData {
                    Section("Weather") {
                        HStack {
                            Text(weather.conditionEmoji)
                                .font(.title)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(weather.temperature)°F")
                                    .font(.headline)
                                Text(weather.condition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Humidity: \(weather.humidity)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let aqi = weather.aqi {
                                    Text("AQI: \(aqi)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else if viewModel.isFetchingWeather {
                    Section("Weather") {
                        HStack {
                            ProgressView()
                            Text("Fetching weather...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Details Section
                Section("Details") {
                    DatePicker("Time", selection: $viewModel.timestamp)

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    viewModel.removeTag(tag)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quick Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createEntry()
                            if viewModel.showSuccess {
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
                isTextFieldFocused = true
                Task {
                    await viewModel.detectCurrentLocation()
                }
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
            .sheet(isPresented: $showPlacePicker) {
                PlacePickerView(
                    places: viewModel.vaultManager.places,
                    currentLocation: viewModel.currentLocation,
                    selectedPlace: $viewModel.selectedPlace
                )
            }
            .journalingSuggestionsPicker(
                isPresented: $viewModel.showSuggestionsPicker,
                onCompletion: { suggestion in
                    // User selected a suggestion
                    Task {
                        await viewModel.handleSuggestion(suggestion)
                    }
                }
            )
        }
    }
}

// MARK: - Tag Chip
struct TagChip: View {
    let tag: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview
#Preview {
    let vaultManager = VaultManager()
    let locationService = LocationService()
    let viewModel = QuickEntryViewModel(vaultManager: vaultManager, locationService: locationService)
    return QuickEntryView(viewModel: viewModel)
}
