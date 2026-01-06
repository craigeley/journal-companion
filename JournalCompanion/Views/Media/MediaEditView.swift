//
//  MediaEditView.swift
//  JournalCompanion
//
//  View for creating and editing media entries
//

import SwiftUI

struct MediaEditView: View {
    @ObservedObject var viewModel: MediaEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Artwork preview section
                if !viewModel.artworkURL.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            artworkPreview
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                // Basic info section
                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                        .onChange(of: viewModel.title) { _, _ in
                            viewModel.validateTitle()
                        }

                    if let error = viewModel.titleError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Media type (read-only in edit mode)
                    HStack {
                        Text("Type")
                        Spacer()
                        Label(viewModel.mediaType.displayName, systemImage: viewModel.mediaType.systemImage)
                            .foregroundStyle(viewModel.mediaType.color)
                    }

                    TextField("Creator", text: $viewModel.creator)

                    TextField("Year", text: $viewModel.releaseYear)
                        .keyboardType(.numberPad)

                    TextField("Genre", text: $viewModel.genre)
                }

                // Tags section
                Section("Tags") {
                    TagEditor(tags: $viewModel.tags)
                }

                // Notes section
                Section("Notes") {
                    TextEditor(text: $viewModel.content)
                        .frame(minHeight: 100)
                }

                // Links section (collapsible)
                Section("Links") {
                    if !viewModel.iTunesURL.isEmpty {
                        Link(destination: URL(string: viewModel.iTunesURL)!) {
                            Label("View on iTunes", systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isCreating ? "Add Media" : "Edit Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isCreating ? "Add" : "Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView("Saving...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        }
    }

    @ViewBuilder
    private var artworkPreview: some View {
        if let url = URL(string: viewModel.artworkURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 150, height: 150)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 150, maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                case .failure:
                    placeholderArtwork
                @unknown default:
                    placeholderArtwork
                }
            }
        } else {
            placeholderArtwork
        }
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.mediaType.color.opacity(0.2))
                .frame(width: 150, height: 150)
            Image(systemName: viewModel.mediaType.systemImage)
                .font(.system(size: 50))
                .foregroundStyle(viewModel.mediaType.color)
        }
    }
}

// MARK: - Tag Editor

struct TagEditor: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.subheadline)
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
            }

            // Add new tag
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        addTag()
                    }

                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
}

// FlowLayout is defined in QuickEntryView.swift
