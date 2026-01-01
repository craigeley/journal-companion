//
//  ValidatedTextEditor.swift
//  JournalCompanion
//
//  TextEditor with inline wiki-link validation
//

import SwiftUI
import UIKit

struct ValidatedTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int?
    let places: [Place]
    let people: [Person]
    let onTextChange: ((String) -> Void)?

    init(
        text: Binding<String>,
        cursorPosition: Binding<Int?> = .constant(nil),
        places: [Place],
        people: [Person],
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self._cursorPosition = cursorPosition
        self.places = places
        self.people = people
        self.onTextChange = onTextChange
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        // Configure for iOS appearance
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.keyboardType = .twitter  // Easy access to @ and # characters

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if text changed externally
        if textView.text != text {
            let selectedRange = textView.selectedRange
            applyStyledText(to: textView, text: text)

            // Apply cursor position if explicitly set
            if let position = cursorPosition, position <= textView.text.count {
                textView.selectedRange = NSRange(location: position, length: 0)
                // Clear the cursor position after applying
                DispatchQueue.main.async {
                    self.cursorPosition = nil
                }
            } else if selectedRange.location <= textView.text.count {
                // Otherwise restore previous cursor position
                textView.selectedRange = selectedRange
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyStyledText(to textView: UITextView, text: String) {
        let attributedString = NSMutableAttributedString(string: text)

        // Apply default text attributes
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        attributedString.addAttributes(defaultAttributes, range: NSRange(location: 0, length: text.count))

        // Parse and style wiki-links
        let wikiLinks = WikiLinkParser.parse(text, places: places, people: people)

        for link in wikiLinks {
            let nsRange = NSRange(link.range, in: text)

            // Validate range before applying attributes
            guard nsRange.location != NSNotFound,
                  nsRange.location >= 0,
                  nsRange.length > 0,
                  nsRange.location + nsRange.length <= attributedString.length else {
                continue
            }

            var attributes: [NSAttributedString.Key: Any] = [:]

            if link.isValid {
                // Valid link - blue and bold
                attributes[.foregroundColor] = UIColor.systemBlue
                attributes[.font] = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
            } else {
                // Invalid link - gray
                attributes[.foregroundColor] = UIColor.systemGray
            }

            attributedString.addAttributes(attributes, range: nsRange)
        }

        textView.attributedText = attributedString
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ValidatedTextEditor

        init(_ parent: ValidatedTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Get plain text
            let newText = textView.text ?? ""

            // Update binding
            parent.text = newText

            // Notify parent
            parent.onTextChange?(newText)

            // Reapply styling
            parent.applyStyledText(to: textView, text: newText)
        }
    }
}

// MARK: - UIFont Extension
private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var text = "Met [[Alice Smith]] at [[Central Park]] today. Had coffee with [[Bob]] (invalid)."

        private let places = [
            Place(id: "central-park", name: "Central Park", location: nil, address: "New York, NY", tags: [], callout: .park, pin: nil, color: nil, url: nil, aliases: [], content: "")
        ]

        private let people = [
            Person(id: "alice", name: "Alice Smith", pronouns: "she/her", relationshipType: .friend, tags: [], email: nil, phone: nil, address: nil, birthday: nil, metDate: nil, color: nil, photoFilename: nil, aliases: [], content: "")
        ]

        var body: some View {
            VStack {
                Text("Wiki-links are highlighted:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Blue = Valid, Gray = Invalid")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ValidatedTextEditor(
                    text: $text,
                    places: places,
                    people: people
                )
                .frame(height: 200)
                .border(Color.gray.opacity(0.3))
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
