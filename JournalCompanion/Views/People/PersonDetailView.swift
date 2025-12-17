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
    @EnvironmentObject var templateManager: TemplateManager

    @State private var currentPerson: Person
    @State private var recentEntries: [Entry] = []
    @State private var isLoadingEntries = false
    @State private var selectedEntry: Entry?
    @State private var showEntryDetail = false
    @State private var showPersonEdit = false

    init(person: Person) {
        self.person = person
        _currentPerson = State(initialValue: person)
    }

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
                                .foregroundStyle(colorForRelationship(currentPerson.relationshipType))

                            Text(currentPerson.name)
                                .font(.title2)
                                .bold()

                            HStack(spacing: 4) {
                                Text(currentPerson.relationshipType.rawValue.capitalized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if templateManager.personTemplate.isEnabled("pronouns"),
                                   let pronouns = currentPerson.pronouns {
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
                if (templateManager.personTemplate.isEnabled("email") && currentPerson.email != nil) ||
                   (templateManager.personTemplate.isEnabled("phone") && currentPerson.phone != nil) ||
                   (templateManager.personTemplate.isEnabled("address") && currentPerson.address != nil) {
                    Section("Contact") {
                        if templateManager.personTemplate.isEnabled("email"),
                           let email = currentPerson.email {
                            LabeledContent("Email") {
                                Link(email, destination: URL(string: "mailto:\(email)")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                        if templateManager.personTemplate.isEnabled("phone"),
                           let phone = currentPerson.phone {
                            LabeledContent("Phone") {
                                Link(phone, destination: URL(string: "tel:\(phone.filter { $0.isNumber })")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                        if templateManager.personTemplate.isEnabled("address"),
                           let address = currentPerson.address {
                            LabeledContent("Address") {
                                Text(address)
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                // Important Dates
                if (templateManager.personTemplate.isEnabled("birthday") && currentPerson.birthday != nil) ||
                   (templateManager.personTemplate.isEnabled("met_date") && currentPerson.metDate != nil) {
                    Section("Important Dates") {
                        if templateManager.personTemplate.isEnabled("birthday"),
                           let birthday = currentPerson.birthday {
                            LabeledContent("Birthday", value: formatBirthday(birthday))
                        }
                        if templateManager.personTemplate.isEnabled("met_date"),
                           let metDate = currentPerson.metDate {
                            LabeledContent("Met", value: metDate, format: .dateTime.month().day().year())
                        }
                    }
                }

                // Tags
                if templateManager.personTemplate.isEnabled("tags") && !currentPerson.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(currentPerson.tags, id: \.self) { tag in
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

                // Aliases
                if templateManager.personTemplate.isEnabled("aliases") && !currentPerson.aliases.isEmpty {
                    Section("Aliases") {
                        ForEach(currentPerson.aliases, id: \.self) { alias in
                            Text(alias)
                        }
                    }
                }

                // Notes
                if !currentPerson.content.isEmpty {
                    Section("Notes") {
                        WikiText(
                            text: currentPerson.content,
                            places: vaultManager.places,
                            people: vaultManager.people,
                            lineLimit: nil,
                            font: .body
                        )
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
                                showEntryDetail = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Person Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showPersonEdit = true
                    }
                }
            }
            .task {
                await loadRecentEntries()
            }
            .sheet(isPresented: $showEntryDetail) {
                if let entry = selectedEntry {
                    EntryDetailView(entry: entry)
                        .environmentObject(vaultManager)
                }
            }
            .onChange(of: showEntryDetail) { _, isShowing in
                if !isShowing {
                    // Reload entries when entry detail view closes
                    Task {
                        await loadRecentEntries()
                    }
                }
            }
            .sheet(isPresented: $showPersonEdit) {
                PersonEditView(viewModel: PersonEditViewModel(
                    person: currentPerson,
                    vaultManager: vaultManager,
                    templateManager: templateManager
                ))
                .environmentObject(templateManager)
            }
            .onChange(of: showPersonEdit) { _, isShowing in
                if !isShowing {
                    // Reload person when edit view closes
                    Task {
                        await reloadPerson()
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
            let personEntries = allEntries.filter { $0.people.contains(currentPerson.name) }

            // Take 5 most recent (already sorted newest first)
            recentEntries = Array(personEntries.prefix(5))
        } catch {
            print("❌ Failed to load entries for person: \(error)")
            recentEntries = []
        }
    }

    private func reloadPerson() async {
        // Reload people from vault to get updated person
        do {
            _ = try await vaultManager.loadPeople()
            // Find the updated person by ID
            if let updatedPerson = vaultManager.people.first(where: { $0.id == currentPerson.id }) {
                currentPerson = updatedPerson
            }
        } catch {
            print("❌ Failed to reload person: \(error)")
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
        guard birthday.month != nil, birthday.day != nil else {
            return "Unknown"
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()

        if birthday.year != nil {
            // Full birthdate with year - show date and calculate age
            let components = birthday
            guard let birthDate = calendar.date(from: components) else {
                return "Unknown"
            }

            formatter.dateFormat = "MMMM d, yyyy"
            let dateString = formatter.string(from: birthDate)

            // Calculate age
            let now = Date()
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
            if let age = ageComponents.year {
                return "\(dateString) (age \(age))"
            } else {
                return dateString
            }
        } else {
            // Only month/day available - show without year
            var components = birthday
            components.year = calendar.component(.year, from: Date())  // Temporary for formatting

            if let date = calendar.date(from: components) {
                formatter.dateFormat = "MMMM d"
                return formatter.string(from: date)
            }
            return "Unknown"
        }
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
        color: "rgb(72,133,237)",
        photoFilename: nil,
        aliases: [],
        content: "Met in college. Great friend and always up for coffee."
    )
    PersonDetailView(person: samplePerson)
        .environmentObject(VaultManager())
}
