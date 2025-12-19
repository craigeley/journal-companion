//
//  SmartTextEditor.swift
//  JournalCompanion
//
//  Text editor with autocomplete and inline wiki-link validation
//

import SwiftUI

struct SmartTextEditor: View {
    @Binding var text: String
    let places: [Place]
    let people: [Person]
    let minHeight: CGFloat
    let showAudioButton: Bool
    let isRecording: Bool
    let onRecordTap: () -> Void

    @StateObject private var autocompleteManager: AutocompleteManager
    @State private var cursorPosition: Int?

    init(
        text: Binding<String>,
        places: [Place],
        people: [Person],
        minHeight: CGFloat = 120,
        showAudioButton: Bool = false,
        isRecording: Bool = false,
        onRecordTap: @escaping () -> Void = {}
    ) {
        self._text = text
        self.places = places
        self.people = people
        self.minHeight = minHeight
        self.showAudioButton = showAudioButton
        self.isRecording = isRecording
        self.onRecordTap = onRecordTap
        self._autocompleteManager = StateObject(wrappedValue: AutocompleteManager(places: places, people: people))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(spacing: 0) {
                // Validated text editor
                ValidatedTextEditor(
                    text: $text,
                    cursorPosition: $cursorPosition,
                    places: places,
                    people: people,
                    onTextChange: { newText in
                        autocompleteManager.updateState(text: newText)
                    }
                )
                .frame(minHeight: minHeight)

                // Autocomplete suggestions
                if autocompleteManager.state.isActive && !autocompleteManager.suggestions.isEmpty {
                    AutocompleteSuggestionView(suggestions: autocompleteManager.suggestions) { suggestion in
                        // Insert suggestion and get cursor position
                        let (newText, position) = autocompleteManager.insertSuggestion(suggestion, into: text)
                        text = newText
                        cursorPosition = position
                        autocompleteManager.updateState(text: text)
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: autocompleteManager.state.isActive)

            // Audio record button
            if showAudioButton {
                AudioRecordButton(
                    isRecording: isRecording,
                    action: onRecordTap
                )
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Met [[Alice Smith]] at [[Central Park]]. Try typing [[ or @"

        private let places = [
            Place(id: "central-park", name: "Central Park", location: nil, address: "New York, NY", tags: [], callout: "park", pin: nil, color: nil, url: nil, aliases: [], content: ""),
            Place(id: "blue-bottle", name: "Blue Bottle Coffee", location: nil, address: "123 Main St", tags: [], callout: "cafe", pin: nil, color: nil, url: nil, aliases: ["BB Coffee"], content: "")
        ]

        private let people = [
            Person(id: "alice", name: "Alice Smith", pronouns: "she/her", relationshipType: .friend, tags: [], email: nil, phone: nil, address: nil, birthday: nil, metDate: nil, color: nil, photoFilename: nil, aliases: ["Ali"], content: ""),
            Person(id: "bob", name: "Bob Jones", pronouns: "he/him", relationshipType: .colleague, tags: [], email: nil, phone: nil, address: nil, birthday: nil, metDate: nil, color: nil, photoFilename: nil, aliases: [], content: "")
        ]

        var body: some View {
            VStack(spacing: 16) {
                Text("Smart Text Editor")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Features:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Type [[ to autocomplete places/people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Type @ to autocomplete people")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Blue links = valid, Gray = invalid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SmartTextEditor(
                    text: $text,
                    places: places,
                    people: people,
                    minHeight: 150
                )
                .border(Color.gray.opacity(0.3))
                .padding()
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
