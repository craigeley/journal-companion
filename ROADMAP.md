# JournalCompanion Roadmap

This document outlines the planned features and implementation strategy for JournalCompanion's future development.

## Overview

Three major feature areas are planned:
1. **Apple Watch App** - Quick entry creation on the go
2. **Audio Journaling** - Record, store, and transcribe audio entries
3. **People Records** - Track relationships alongside Places and Entries

---

## Feature 1: Apple Watch App

### Goal
Enable users to quickly capture journal entries from Apple Watch that can be edited later on iPhone to add metadata (place, weather, tags, etc.).

### Use Cases
- Quick thought capture while walking/exercising
- Voice dictation without taking out iPhone
- Immediate journaling of moments (before context is forgotten)
- Offline entry creation (synced when iPhone is nearby)

### Architecture

#### 1. Watch App Target
Create a new WatchOS app target within the existing project:
- **Target Name**: `JournalCompanion Watch App`
- **Min WatchOS**: 10.0+ (for latest SwiftUI features)
- **Complications**: Show entry count or quick-add shortcut

#### 2. Shared Code via Swift Package
Create local Swift Package for shared models:
```
JournalCompanionShared/
├── Sources/
│   ├── Models/
│   │   ├── Entry.swift (shared subset)
│   │   ├── SimpleEntry.swift (watch-optimized)
│   │   └── SyncState.swift
│   └── Utilities/
│       └── DateFormatters.swift
```

**SimpleEntry Model** (optimized for Watch):
```swift
struct SimpleEntry: Identifiable, Codable, Sendable {
    let id: String
    let dateCreated: Date
    var content: String
    var tags: [String] = ["entry", "watch"]
    var needsSync: Bool = true
    var isEditedOniPhone: Bool = false
}
```

#### 3. Watch Connectivity
Use **WatchConnectivity framework** for bidirectional sync:
- **Watch → iPhone**: Send new SimpleEntry via `transferUserInfo()` (background)
- **iPhone → Watch**: Confirm entry creation, send entry count
- **Session State**: Monitor reachability for immediate vs queued sync

**WatchConnectivityService** (actor):
```swift
actor WatchConnectivityService {
    func sendEntry(_ entry: SimpleEntry) async throws
    func requestSync() async throws
    func receiveEntry(userInfo: [String: Any]) async -> SimpleEntry?
}
```

#### 4. iPhone Receiver
New service to handle incoming Watch entries:
- **WatchEntryReceiver** (actor):
  - Receives SimpleEntry from Watch
  - Converts to full Entry model (adds empty metadata)
  - Writes to vault via EntryWriter
  - Marks as "pending enhancement" in metadata
  - Sends confirmation back to Watch

**Entry Enhancement Flow**:
1. Watch entry arrives → saved to vault immediately
2. User opens iPhone app → "Pending Entries" badge shown
3. Tap entry → QuickEntryView opens with pre-filled content
4. User adds place, adjusts timestamp, reviews weather
5. Save → entry updated with full metadata

#### 5. Watch UI

**Main Watch View** (WatchQuickEntryView):
- Large "New Entry" button
- Text input via dictation or scribble
- Immediate save (no cancel - just don't save if empty)
- Success animation
- Entry count badge

**Complications**:
- **Circular**: Entry count for today
- **Corner**: Quick-add icon
- **Rectangular**: "X entries today"

#### 6. Data Persistence on Watch

Use **SwiftData** for local storage:
- Store entries locally until sync confirmed
- Show sync status (pending/synced)
- Retry failed syncs automatically
- Clear synced entries after confirmation

**SyncStatus States**:
- `.pending` - Not yet sent to iPhone
- `.syncing` - Transfer in progress
- `.synced` - Confirmed by iPhone
- `.failed` - Needs retry

### Implementation Phases

**Phase 1: Basic Watch App (Week 1-2)**
- [ ] Create Watch app target
- [ ] Implement SimpleEntry model
- [ ] Build WatchQuickEntryView (text input only)
- [ ] Local SwiftData persistence
- [ ] Show entry list on Watch

**Phase 2: Watch Connectivity (Week 2-3)**
- [ ] Implement WatchConnectivityService
- [ ] Build WatchEntryReceiver on iPhone
- [ ] Bidirectional sync with retry logic
- [ ] Sync status indicators
- [ ] Background sync when reachable

**Phase 3: iPhone Enhancement Flow (Week 3-4)**
- [ ] Add "Pending Entries" filter/badge
- [ ] Detect and highlight Watch entries needing metadata
- [ ] Pre-populate QuickEntryView from Watch entry
- [ ] Update sync status after enhancement

**Phase 4: Complications & Polish (Week 4)**
- [ ] Add Watch complications
- [ ] Haptic feedback on success
- [ ] Loading/error states
- [ ] Offline handling
- [ ] Settings sync (default tags, etc.)

### Technical Decisions

**Why WatchConnectivity over CloudKit?**
- Faster sync when iPhone nearby
- No separate iCloud container setup needed
- Simpler state management
- Falls back to background transfer when not reachable

**Why SwiftData on Watch?**
- Modern declarative API
- Automatic persistence
- Query support for pending entries
- Less boilerplate than Core Data

**Metadata Strategy**:
- Watch entries have minimal metadata (timestamp, content, tags)
- Weather/place added later on iPhone (can't reliably get on Watch)
- User can choose to enhance or leave as-is

### Files to Create

**Watch App**:
- `JournalCompanion Watch App/App/WatchApp.swift`
- `JournalCompanion Watch App/Views/WatchQuickEntryView.swift`
- `JournalCompanion Watch App/ViewModels/WatchEntryViewModel.swift`
- `JournalCompanion Watch App/Services/WatchConnectivityService.swift`
- `JournalCompanion Watch App/Models/SimpleEntry+SwiftData.swift`

**iPhone App**:
- `Services/WatchSync/WatchEntryReceiver.swift`
- `Services/WatchSync/WatchConnectivityManager.swift`
- `ViewModels/PendingEntriesViewModel.swift`

**Shared Package**:
- `JournalCompanionShared/Sources/Models/SimpleEntry.swift`
- `JournalCompanionShared/Sources/Models/SyncState.swift`

---

## Feature 2: Audio Journaling

### Goal
Record audio entries with automatic transcription, store in lossless format, and attach to journal entries with full-text search support.

### Use Cases
- Voice journaling while driving/commuting
- Capture long-form thoughts without typing
- Preserve tone/emotion (audio + transcript)
- Search transcripts to find entries
- Playback speed control for review

### Architecture

#### 1. Audio Data Model

**AudioAttachment Model**:
```swift
struct AudioAttachment: Identifiable, Codable, Sendable {
    let id: String  // UUID
    let filename: String  // e.g., "202501151430-audio.m4a"
    let duration: TimeInterval
    let fileSize: Int64  // bytes
    let format: AudioFormat  // .alac (lossless)
    var transcript: String?
    var transcriptionState: TranscriptionState
    let dateRecorded: Date
}

enum AudioFormat: String, Codable {
    case alac = "m4a"  // Apple Lossless
}

enum TranscriptionState: String, Codable {
    case pending
    case transcribing
    case completed
    case failed
    case unavailable  // offline or no permission
}
```

**Entry Model Update**:
```swift
// Add to Entry.swift:
var audioAttachments: [AudioAttachment] = []

// In toMarkdown():
if !audioAttachments.isEmpty {
    yaml += "audio:\n"
    for audio in audioAttachments {
        yaml += "  - file: \(audio.filename)\n"
        yaml += "    duration: \(audio.duration)\n"
        if let transcript = audio.transcript {
            yaml += "    transcript: \"\(transcript.replacingOccurrences(of: "\"", with: "\\\""))\"\n"
        }
    }
}
```

#### 2. Audio Storage Structure

**Vault Layout**:
```
Vault/
├── Entries/
│   └── 2025/01-January/15/
│       └── 202501151430.md
└── Audio/
    └── 2025/01-January/15/
        ├── 202501151430-audio-1.m4a
        ├── 202501151430-audio-2.m4a
        └── 202501151431-audio.m4a
```

**Naming Convention**:
- Format: `{YYYYMMDDHHmm}-audio-{index}.m4a`
- Index increments if multiple recordings for same entry
- Mirrors entry directory structure

#### 3. Recording Service

**AudioRecordingService** (actor):
```swift
actor AudioRecordingService {
    private let audioEngine: AVAudioEngine
    private let audioFile: AVAudioFile?
    private var isRecording: Bool = false

    // Use ALAC format (lossless)
    private let audioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48000,
        channels: 1,
        interleaved: false
    )

    func startRecording() async throws
    func stopRecording() async throws -> URL
    func pauseRecording() async throws
    func resumeRecording() async throws

    var currentDuration: TimeInterval { get async }
    var recordingLevel: Float { get async }  // for waveform visualization
}
```

**Recording Flow**:
1. Request microphone permission (AVAudioSession)
2. Configure audio session for recording
3. Start AVAudioEngine with ALAC encoder
4. Real-time level monitoring for UI
5. Stop → convert to .m4a (ALAC codec)
6. Return file URL

#### 4. Transcription Service

Use **Speech framework** with `SFSpeechRecognizer`:

**TranscriptionService** (actor):
```swift
actor TranscriptionService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func transcribe(audioURL: URL) async throws -> String {
        // Request speech recognition permission
        // Use SFSpeechURLRecognitionRequest for file-based transcription
        // Return final transcript string
    }

    func transcribeRealtime(
        audioBuffer: AVAudioPCMBuffer
    ) async throws -> String {
        // For live transcription during recording (optional)
    }

    var isAvailable: Bool { get async }
}
```

**Transcription Strategy**:
- **On-device only**: Use Speech framework (free, private)
- **Post-recording**: Transcribe after recording completes
- **Background processing**: Queue transcriptions for offline entries
- **Language detection**: Auto-detect or use system language
- **Punctuation**: Enable automatic punctuation in recognizer

#### 5. Audio Writer

**AudioWriter** (actor):
```swift
actor AudioWriter {
    private let vaultURL: URL

    func write(
        audioURL: URL,
        for entry: Entry,
        transcript: String?
    ) async throws -> AudioAttachment {
        // 1. Generate audio filename
        // 2. Create Audio/YYYY/MM-Month/DD/ directory
        // 3. Move audio file to vault (atomic)
        // 4. Create AudioAttachment record
        // 5. Return attachment for adding to Entry
    }

    func delete(attachment: AudioAttachment, for entry: Entry) async throws {
        // Delete audio file from vault
    }
}
```

#### 6. UI Components

**AudioRecorderView** (SwiftUI):
```swift
struct AudioRecorderView: View {
    @StateObject var viewModel: AudioRecorderViewModel

    var body: some View {
        VStack {
            // Waveform visualization (live recording levels)
            AudioWaveformView(levels: viewModel.recordingLevels)

            // Duration display
            Text(viewModel.formattedDuration)
                .font(.system(.title, design: .monospaced))

            // Recording controls
            HStack {
                if viewModel.isRecording {
                    Button("Pause") { viewModel.pauseRecording() }
                    Button("Stop") { viewModel.stopRecording() }
                } else if viewModel.isPaused {
                    Button("Resume") { viewModel.resumeRecording() }
                    Button("Stop") { viewModel.stopRecording() }
                } else {
                    Button("Record") { viewModel.startRecording() }
                }
            }

            // Transcription preview (if live transcription enabled)
            if let transcript = viewModel.liveTranscript {
                Text(transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

**AudioPlaybackView**:
```swift
struct AudioPlaybackView: View {
    let attachment: AudioAttachment
    @StateObject var player: AudioPlayerViewModel

    var body: some View {
        VStack {
            // Playback controls
            HStack {
                Button(action: { player.playPause() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }

                Slider(value: $player.currentTime, in: 0...attachment.duration)

                Text(player.formattedRemainingTime)
                    .font(.caption)
                    .monospacedDigit()
            }

            // Playback speed
            Picker("Speed", selection: $player.playbackSpeed) {
                Text("0.5x").tag(0.5)
                Text("1.0x").tag(1.0)
                Text("1.5x").tag(1.5)
                Text("2.0x").tag(2.0)
            }
            .pickerStyle(.segmented)

            // Transcript (if available)
            if let transcript = attachment.transcript {
                ScrollView {
                    Text(transcript)
                        .textSelection(.enabled)
                }
            } else if attachment.transcriptionState == .transcribing {
                ProgressView("Transcribing...")
            }
        }
    }
}
```

**Integration into QuickEntryView**:
```swift
// Add to QuickEntryView:
Section("Audio") {
    if viewModel.audioAttachments.isEmpty {
        Button("Record Audio") {
            showAudioRecorder = true
        }
    } else {
        ForEach(viewModel.audioAttachments) { audio in
            AudioPlaybackView(attachment: audio, player: makePlayer(for: audio))
        }
        Button("Add Another Recording") {
            showAudioRecorder = true
        }
    }
}
.sheet(isPresented: $showAudioRecorder) {
    AudioRecorderView(viewModel: AudioRecorderViewModel())
}
```

#### 7. Search Integration

Extend entry search to include audio transcripts:

**EntrySearcher** update:
```swift
func search(query: String) -> [Entry] {
    entries.filter { entry in
        // Existing: content, tags, place
        entry.content.localizedCaseInsensitiveContains(query) ||
        entry.tags.contains { $0.localizedCaseInsensitiveContains(query) } ||

        // NEW: Audio transcripts
        entry.audioAttachments.contains { audio in
            audio.transcript?.localizedCaseInsensitiveContains(query) ?? false
        }
    }
}
```

### Implementation Phases

**Phase 1: Audio Recording (Week 1-2)**
- [ ] Create AudioAttachment model
- [ ] Implement AudioRecordingService with ALAC format
- [ ] Build AudioRecorderView with waveform visualization
- [ ] Request microphone permissions
- [ ] Save audio files to vault structure
- [ ] AudioWriter actor for file management

**Phase 2: Basic Playback (Week 2)**
- [ ] Implement AudioPlayerViewModel
- [ ] Build AudioPlaybackView with controls
- [ ] Playback speed control
- [ ] Progress slider
- [ ] Duration formatting

**Phase 3: Transcription (Week 3)**
- [ ] Implement TranscriptionService with Speech framework
- [ ] Request speech recognition permissions
- [ ] Post-recording transcription
- [ ] Show transcription state in UI
- [ ] Store transcripts in YAML frontmatter
- [ ] Retry failed transcriptions

**Phase 4: Integration & Search (Week 4)**
- [ ] Update Entry model with audio array
- [ ] Integrate recorder into QuickEntryView
- [ ] Update EntryReader to parse audio metadata
- [ ] Extend search to include transcripts
- [ ] Audio attachment management (delete, reorder)
- [ ] Background transcription queue

**Phase 5: Advanced Features (Week 5)**
- [ ] Live transcription during recording (optional)
- [ ] Multiple audio attachments per entry
- [ ] Audio trimming/editing
- [ ] Export audio files
- [ ] Audio-only entry type
- [ ] Voice command to start recording

### Technical Decisions

**Why ALAC over MP3/AAC?**
- Lossless quality preserves original audio
- Apple native format (.m4a container)
- Smaller than WAV but higher quality than AAC
- Good balance: quality vs file size

**Why Speech Framework over cloud APIs?**
- Free (no API costs)
- Private (on-device only)
- Works offline
- Low latency
- Native iOS integration

**Storage in Vault**:
- Audio files alongside markdown (not database)
- Easy backup (files are portable)
- Obsidian plugins can potentially play audio
- Transcript searchable in any text editor

**Transcription Timing**:
- Post-recording (not live) to avoid UI lag
- Background queue for batch processing
- User can save entry before transcription completes
- Transcript added to entry when ready (atomic update)

### Files to Create

**Models**:
- `Models/AudioAttachment.swift`

**Services**:
- `Services/Audio/AudioRecordingService.swift`
- `Services/Audio/TranscriptionService.swift`
- `Services/FileSystem/AudioWriter.swift`
- `Services/Audio/AudioPlayerService.swift`

**ViewModels**:
- `ViewModels/AudioRecorderViewModel.swift`
- `ViewModels/AudioPlayerViewModel.swift`

**Views**:
- `Views/Audio/AudioRecorderView.swift`
- `Views/Audio/AudioPlaybackView.swift`
- `Views/Audio/AudioWaveformView.swift`

---

## Feature 3: People Records

### Goal
Create a "People" entity similar to Places to track relationships, interactions, and connections with individuals mentioned in journal entries.

### Use Cases
- Link entries to specific people
- Track interactions over time
- See all entries involving a person
- Contact info storage (phone, email, social media)
- Relationship metadata (friend, family, colleague)
- Birthday/anniversary reminders
- Visualize relationship timeline

### Architecture

#### 1. Person Data Model

**Person Model**:
```swift
struct Person: Identifiable, Codable, Sendable {
    let id: String  // Sanitized filename (without .md)
    var name: String
    var pronouns: String?  // they/them, she/her, he/him, etc.
    var relationshipType: RelationshipType
    var tags: [String]  // family, work, friend, etc.
    var contactInfo: ContactInfo?
    var birthday: DateComponents?  // month/day only
    var metDate: Date?  // when you met this person
    var socialMedia: [SocialMediaLink]
    var color: String?  // rgb(72,133,237) for UI theming
    var photo: String?  // filename of photo in People/Photos/
    var content: String  // Body text (notes about the person)

    var filename: String {
        id + ".md"
    }
}

enum RelationshipType: String, Codable {
    case family
    case friend
    case colleague
    case acquaintance
    case partner
    case mentor
    case other
}

struct ContactInfo: Codable {
    var email: String?
    var phone: String?
    var address: String?
}

struct SocialMediaLink: Codable, Identifiable {
    let id = UUID()
    let platform: String  // Twitter, Instagram, LinkedIn, etc.
    let username: String
    let url: String?
}
```

#### 2. Vault Structure

**File Layout**:
```
Vault/
├── People/
│   ├── Alice-Smith.md
│   ├── Bob-Jones.md
│   └── Photos/
│       ├── Alice-Smith.jpg
│       └── Bob-Jones.jpg
├── Entries/
│   └── 2025/01-January/15/
│       └── 202501151430.md
```

**Person Markdown Format**:
```markdown
---
pronouns: she/her
relationship: friend
tags: [climbing, tech, college]
email: alice@example.com
phone: +1-555-0123
birthday: 03-15  # March 15 (no year for privacy)
met_date: 2018-09-01
social:
  - platform: Instagram
    username: alice_smith
  - platform: LinkedIn
    username: alicesmith
color: rgb(255,149,0)
photo: Alice-Smith.jpg
---

Met Alice at university in 2018. She's a software engineer who loves rock climbing.

Last saw her on 2025-01-10 for coffee.
```

#### 3. Entry Linking

**Update Entry Model**:
```swift
// Add to Entry.swift:
var people: [String]?  // Array of person names (without brackets)

// In toMarkdown():
if let people = people, !people.isEmpty {
    yaml += "people:\n"
    for person in people {
        yaml += "  - \"[[\(person)]]\"\n"
    }
}
```

**Linking Format** (wikilink style):
```markdown
---
date_created: 2025-01-15T14:30:00.000-08:00
tags: [coffee, weekend]
people:
  - "[[Alice Smith]]"
  - "[[Bob Jones]]"
---

Had coffee with Alice and Bob today. Alice told me about her new climbing project.
```

#### 4. Services

**PersonWriter** (actor):
```swift
actor PersonWriter {
    private let vaultURL: URL

    func write(person: Person) async throws {
        // Create People/ directory if needed
        // Write person to People/{sanitized-name}.md
        // Save photo if provided
    }

    func update(person: Person) async throws {
        // Update existing person file
    }

    func delete(person: Person) async throws {
        // Delete person file and photo
        // Don't delete entry links (keep wikilinks as text)
    }
}
```

**PersonReader** (actor):
```swift
actor PersonReader {
    func readAll(from vaultURL: URL) async throws -> [Person] {
        // Read all .md files from People/ directory
        // Parse YAML frontmatter
        // Return array of Person objects
    }

    func read(filename: String, from vaultURL: URL) async throws -> Person? {
        // Read single person file
    }
}
```

#### 5. VaultManager Integration

**Update VaultManager**:
```swift
@MainActor
class VaultManager: ObservableObject {
    @Published var places: [Place] = []
    @Published var people: [Person] = []  // NEW

    private func loadPeople() async {
        guard let vaultURL = vaultURL else { return }

        do {
            let reader = PersonReader()
            let loadedPeople = try await reader.readAll(from: vaultURL)

            await MainActor.run {
                self.people = loadedPeople
            }
        } catch {
            print("❌ Failed to load people: \(error)")
        }
    }

    func refreshPeople() async {
        await loadPeople()
    }
}
```

#### 6. UI Components

**PeopleListView**:
```swift
struct PeopleListView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchText = ""
    @State private var selectedRelationshipFilter: RelationshipType?

    var filteredPeople: [Person] {
        vaultManager.people.filter { person in
            (searchText.isEmpty || person.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedRelationshipFilter == nil || person.relationshipType == selectedRelationshipFilter)
        }
    }

    var body: some View {
        List {
            ForEach(filteredPeople) { person in
                NavigationLink(destination: PersonDetailView(person: person)) {
                    PersonRowView(person: person)
                }
            }
        }
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Person") {
                    // Show PersonCreationView
                }
            }
        }
    }
}
```

**PersonRowView**:
```swift
struct PersonRowView: View {
    let person: Person

    var body: some View {
        HStack {
            // Photo or initials avatar
            if let photoName = person.photo {
                AsyncImage(url: photoURL(for: photoName)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Text(person.initials)
                    .font(.headline)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading) {
                Text(person.name)
                    .font(.headline)

                HStack {
                    Text(person.relationshipType.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())

                    if let pronouns = person.pronouns {
                        Text(pronouns)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Entry count badge
            Text("\(entryCount) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var entryCount: Int {
        // Count entries that mention this person
        // (requires VaultManager access or pass as parameter)
        0
    }
}
```

**PersonDetailView**:
```swift
struct PersonDetailView: View {
    let person: Person
    @EnvironmentObject var vaultManager: VaultManager

    var relatedEntries: [Entry] {
        // Find all entries that mention this person
        vaultManager.entries.filter { entry in
            entry.people?.contains(person.name) ?? false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with photo and basic info
                PersonHeaderView(person: person)

                // Contact info section
                if let contact = person.contactInfo {
                    ContactInfoView(contact: contact)
                }

                // Social media links
                if !person.socialMedia.isEmpty {
                    SocialMediaView(links: person.socialMedia)
                }

                // Notes
                if !person.content.isEmpty {
                    Text(person.content)
                        .padding()
                }

                // Related entries timeline
                Section("Related Entries") {
                    ForEach(relatedEntries) { entry in
                        EntryRowView(entry: entry)
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    // Show PersonEditView
                }
            }
        }
    }
}
```

**PersonCreationView** (similar to PlaceCreationView):
```swift
struct PersonCreationView: View {
    @StateObject var viewModel: PersonCreationViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Pronouns (optional)", text: $viewModel.pronouns)
                    Picker("Relationship", selection: $viewModel.relationshipType) {
                        ForEach(RelationshipType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }

                Section("Contact") {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $viewModel.phone)
                        .keyboardType(.phonePad)
                }

                Section("Dates") {
                    DatePicker("Birthday", selection: $viewModel.birthday, displayedComponents: .date)
                    DatePicker("Met On", selection: $viewModel.metDate, displayedComponents: .date)
                }

                Section("Tags") {
                    // Tag editor (similar to QuickEntryView)
                }

                Section("Notes") {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Person")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.createPerson()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

**PersonPickerView** (for linking to entries):
```swift
struct PersonPickerView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Binding var selectedPeople: [Person]
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(vaultManager.people) { person in
                    Button {
                        toggleSelection(person)
                    } label: {
                        HStack {
                            PersonRowView(person: person)
                            Spacer()
                            if selectedPeople.contains(where: { $0.id == person.id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select People")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggleSelection(_ person: Person) {
        if let index = selectedPeople.firstIndex(where: { $0.id == person.id }) {
            selectedPeople.remove(at: index)
        } else {
            selectedPeople.append(person)
        }
    }
}
```

**Integration into QuickEntryView**:
```swift
// Add to QuickEntryView Form:
Section("People") {
    if viewModel.selectedPeople.isEmpty {
        Button("Add People") {
            showPersonPicker = true
        }
    } else {
        ForEach(viewModel.selectedPeople) { person in
            HStack {
                Text(person.name)
                Spacer()
                Button {
                    viewModel.removePerson(person)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        Button("Add More") {
            showPersonPicker = true
        }
    }
}
.sheet(isPresented: $showPersonPicker) {
    PersonPickerView(selectedPeople: $viewModel.selectedPeople)
        .environmentObject(viewModel.vaultManager)
}
```

#### 7. Timeline & Analytics

**PersonTimelineView**:
- Chronological list of all entries mentioning person
- Group by date
- Show entry snippets
- Filter by entry type (audio, text, place visits)

**RelationshipAnalyticsView** (optional):
- Interaction frequency graph
- Last contact date
- Most common places met
- Most common tags in shared entries

### Implementation Phases

**Phase 1: Core Person Model (Week 1)**
- [ ] Create Person model with full metadata
- [ ] Implement PersonWriter actor
- [ ] Implement PersonReader actor
- [ ] Update VaultManager to load people
- [ ] Markdown parsing and generation

**Phase 2: Basic UI (Week 2)**
- [ ] Build PeopleListView with search/filter
- [ ] Build PersonRowView
- [ ] Build PersonDetailView
- [ ] Build PersonCreationView
- [ ] Photo upload/selection

**Phase 3: Entry Linking (Week 3)**
- [ ] Update Entry model with people array
- [ ] Build PersonPickerView
- [ ] Integrate into QuickEntryView
- [ ] Update EntryReader to parse people links
- [ ] Update EntryWriter to serialize people array

**Phase 4: Timeline & Search (Week 4)**
- [ ] Build PersonTimelineView
- [ ] Filter entries by person in main entry list
- [ ] Add people filter to search
- [ ] Related entries count badges
- [ ] Quick actions (call, email, message)

**Phase 5: Advanced Features (Week 5)**
- [ ] Birthday/anniversary reminders
- [ ] Contact import from system Contacts
- [ ] Relationship type analytics
- [ ] Export person profile
- [ ] Bulk operations (merge duplicates)

### Technical Decisions

**Why Not Use Contacts Framework?**
- More control over metadata structure
- Can add custom fields (met date, relationship notes)
- No sync issues with system contacts
- Privacy (keep journaling separate from system)
- But: Optional import from Contacts for convenience

**Pronouns Field**:
- Free-text to support all identities
- Stored in frontmatter for Obsidian compatibility
- Optional but encouraged

**Photo Storage**:
- Store in `People/Photos/` subdirectory
- Reference by filename in YAML
- Support common formats (JPG, PNG)
- Optional compression for performance

**Privacy Considerations**:
- No automatic contact syncing
- Birthdays stored as month-day only (no year)
- User controls what info to store
- No cloud sync (vault only)

### Files to Create

**Models**:
- `Models/Person.swift`
- `Models/RelationshipType.swift`
- `Models/ContactInfo.swift`

**Services**:
- `Services/FileSystem/PersonWriter.swift`
- `Services/FileSystem/PersonReader.swift`

**ViewModels**:
- `ViewModels/PersonCreationViewModel.swift`
- `ViewModels/PersonDetailViewModel.swift`

**Views**:
- `Views/People/PeopleListView.swift`
- `Views/People/PersonRowView.swift`
- `Views/People/PersonDetailView.swift`
- `Views/People/PersonCreationView.swift`
- `Views/People/PersonPickerView.swift`
- `Views/People/PersonTimelineView.swift`
- `Views/People/PersonHeaderView.swift`

---

## Integration & Cross-Feature Synergies

### Watch + Audio
- Record audio entries directly from Watch (voice note style)
- Auto-transcribe and sync to iPhone
- Quick voice capture without opening full recorder

### Audio + People
- Tag people in audio entries via transcript keywords
- "Mentioned: Alice Smith" detected from transcript
- Link people to audio conversations

### People + Places
- Track which people you meet at specific places
- "Coffee meetings with Alice" → list of cafe entries
- Location-based relationship insights

### All Three Together
**Example Use Case**:
1. User at coffee shop with friend
2. Creates Watch entry: "Great convo with Alice"
3. Records 5-minute audio discussing ideas
4. iPhone receives entry, transcribes audio
5. Auto-detects: Place = "Blue Bottle Coffee", Person = "Alice Smith"
6. User confirms auto-links, adds tags
7. Entry saved with: timestamp, place, person, audio, transcript, weather

---

## Development Timeline

### Quarter 1 (Months 1-3)
- **Month 1**: Apple Watch App (Phases 1-4)
- **Month 2**: Audio Journaling (Phases 1-3)
- **Month 3**: Audio Journaling (Phases 4-5) + People Records (Phase 1)

### Quarter 2 (Months 4-6)
- **Month 4**: People Records (Phases 2-3)
- **Month 5**: People Records (Phases 4-5)
- **Month 6**: Integration, polish, bug fixes

### Quarter 3 (Month 7+)
- Synergy features (Watch + Audio, Audio + People)
- Advanced analytics
- User testing and refinement

---

## Technical Dependencies

### Frameworks & APIs
- **WatchConnectivity**: Watch-iPhone sync
- **SwiftData**: Watch local persistence
- **AVFoundation**: Audio recording/playback
- **Speech**: On-device transcription
- **JournalingSuggestions**: Already integrated (iOS 17.2+)
- **WeatherKit**: Already integrated
- **MapKit**: Already integrated

### Minimum OS Versions
- **iOS**: 17.2+ (for JournalingSuggestions)
- **WatchOS**: 10.0+ (for latest SwiftUI)
- **macOS**: N/A (iOS-only app for now)

### Permissions Required
- **Microphone**: Audio recording
- **Speech Recognition**: Transcription
- **Location**: Weather (already granted)
- **Contacts**: Optional import for People

---

## Success Metrics

### Apple Watch App
- [ ] 80%+ sync success rate
- [ ] <5 second sync time when iPhone nearby
- [ ] <30 second entry creation time (from wrist raise to saved)
- [ ] Watch complications work reliably

### Audio Journaling
- [ ] <2% transcription error rate (English)
- [ ] Transcription completes within 30 seconds for 5-minute audio
- [ ] <10MB file size for 5-minute lossless audio
- [ ] Audio playback works offline

### People Records
- [ ] Support 500+ people without performance issues
- [ ] <1 second to filter/search people list
- [ ] Entry linking works for 1000+ entries
- [ ] Zero data loss during file operations

---

## Future Considerations (Post-Roadmap)

### Phase 4+ Ideas
- **iPad App**: Optimized layouts, Split View support
- **Mac App**: Catalyst or native SwiftUI, menubar app
- **Widgets**: Home screen/lock screen entry counts
- **Shortcuts**: Siri integration for voice entry creation
- **Export**: PDF, DOCX, JSON export options
- **Themes**: Custom color schemes and typography
- **Plugins**: Obsidian-style community plugins
- **Encryption**: End-to-end encryption option
- **Cloud Sync**: Optional iCloud sync (alternative to Obsidian Sync)
- **Collaboration**: Shared journals for couples/families
- **AI Features**: Sentiment analysis, memory suggestions, writing prompts

---

## Notes

This roadmap is a living document. Features may be reprioritized based on:
- User feedback
- Technical feasibility discoveries
- Platform API changes
- Development velocity

**Last Updated**: 2025-01-15

**Status**: Planning Phase - Ready for implementation
