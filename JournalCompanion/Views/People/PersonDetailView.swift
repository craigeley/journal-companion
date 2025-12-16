//
//  PersonDetailView.swift
//  JournalCompanion
//
//  Detail view for displaying comprehensive person information
//

import SwiftUI
import CoreLocation

struct PersonDetailView: View {
    let person: Person
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var vaultManager: VaultManager

    @State private var recentEntries: [Entry] = []
    @State private var isLoadingEntries = false
    @State private var selectedEntry: Entry?
    @State private var showEditView = false

    var body: some View {
        NavigationStack {
            List {
                // Header Section with Icon
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(colorForRelationship(person.relationshipType))

                            Text(person.name)
                                .font(.title2)
                                .bold()

                            HStack(spacing: 4) {
                                Text(person.relationshipType.rawValue.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let pronouns = person.pronouns {
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(pronouns)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                // Contact Info
                if person.email != nil || person.phone != nil || person.address != nil {
                    Section("Contact") {
                        if let email = person.email {
                            LabeledContent("Email") {
                                Link(email, destination: URL(string: "mailto:\(email)")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                        if let phone = person.phone {
                            LabeledContent("Phone") {
                                Link(phone, destination: URL(string: "tel:\(phone.filter { $0.isNumber })")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                        if let address = person.address {
                            LabeledContent("Address") {
                                Text(address)
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                // Important Dates
                if person.birthday != nil || person.metDate != nil {
                    Section("Important Dates") {
                        if let birthday = person.birthday {
                            LabeledContent("Birthday", value: formatBirthday(birthday))
                        }
                        if let metDate = person.metDate {
                            LabeledContent("Met", value: metDate, format: .dateTime.month().day().year())
                        }
                    }
                }

                // Social Media
                if !person.socialMedia.isEmpty {
                    Section("Social Media") {
                        ForEach(Array(person.socialMedia.sorted(by: { $0.key < $1.key })), id: \.key) { platform, handle in
                            LabeledContent(platform.capitalized, value: "@\(handle)")
                        }
                    }
                }

                // Tags
                if !person.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(person.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Notes
                if !person.content.isEmpty {
                    Section("Notes") {
                        Text(person.content)
                            .font(.body)
                    }
                }

                // Recent Entries
                Section("Recent Entries") {
                    if isLoadingEntries {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if recentEntries.isEmpty {
                        Text("No entries yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.dateCreated, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(entry.dateCreated, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                WikiText(
                                    text: entry.content,
                                    places: vaultManager.places,
                                    people: vaultManager.people,
                                    lineLimit: 2,
                                    font: .body
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                                showEditView = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Person Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadRecentEntries()
            }
            .sheet(isPresented: $showEditView) {
                if let entry = selectedEntry {
                    EntryEditView(
                        viewModel: EntryEditViewModel(
                            entry: entry,
                            vaultManager: vaultManager,
                            locationService: LocationService()
                        )
                    )
                }
            }
            .onChange(of: showEditView) { _, isShowing in
                if !isShowing {
                    // Reload entries when edit view closes
                    Task {
                        await loadRecentEntries()
                    }
                }
            }
        }
    }

    private func loadRecentEntries() async {
        isLoadingEntries = true
        defer { isLoadingEntries = false }

        guard let vaultURL = vaultManager.vaultURL else { return }

        do {
            let reader = EntryReader(vaultURL: vaultURL)
            let allEntries = try await reader.loadEntries(limit: 100)

            // Filter entries that reference this person
            let personEntries = allEntries.filter { $0.people.contains(person.name) }

            // Take 5 most recent (already sorted newest first)
            recentEntries = Array(personEntries.prefix(5))
        } catch {
            print("❌ Failed to load entries for person: \(error)")
            recentEntries = []
        }
    }

    private func colorForRelationship(_ type: RelationshipType) -> Color {
        switch type {
        case .family: return .red
        case .friend: return .blue
        case .colleague: return .green
        case .acquaintance: return .gray
        case .partner: return .pink
        case .mentor: return .purple
        case .other: return .orange
        }
    }

    private func formatBirthday(_ birthday: DateComponents) -> String {
        let calendar = Calendar.current
        if let date = calendar.date(from: birthday) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date)
        }
        return "Unknown"
    }
}

// MARK: - Preview
#Preview {
    let samplePerson = Person(
        id: "alice-smith",
        name: "Alice Smith",
        pronouns: "she/her",
        relationshipType: .friend,
        tags: ["close", "college"],
        email: "alice@example.com",
        phone: "+1-555-123-4567",
        address: "123 Main St, San Francisco, CA",
        birthday: DateComponents(month: 3, day: 15),
        metDate: Date(),
        socialMedia: ["instagram": "alicesmith"],
        color: "rgb(72,133,237)",
        photoFilename: nil,
        content: "Met in college. Great friend and always up for coffee."
    )
    PersonDetailView(person: samplePerson)
        .environmentObject(VaultManager())
}
