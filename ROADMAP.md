# JournalCompanion Feature Roadmap

This document contains implementation plans for upcoming features, serving as a reference for future development work.

---

# Feature 1: Photo Entry Type ✅ COMPLETED

**Completed:** December 22, 2025

## Summary of Implementation

Photo entry creation with EXIF metadata extraction and hero zoom preview.

### What Was Built

**New Files:**
- `PhotoEXIF.swift` - EXIF metadata model and extraction
- `PhotoFileManager.swift` - Actor for photo file I/O
- `PhotoEntryViewModel.swift` - Photo entry state management
- `PhotoEntryView.swift` - Photo entry creation UI
- `QuickLookPresenter` (in EntryDetailView) - Hero zoom fullscreen preview

**Modified Files:**
- `ContentView.swift` - Added Photo Entry button to FAB menu
- `Entry.swift` - Added photo entry support (isPhotoEntry, photoAttachment, camera metadata)
- `EntryListView.swift` - Photo thumbnails in entry rows
- `EntryDetailView.swift` - Photo display with hero zoom to fullscreen

### Features Delivered
- Single photo per entry from iOS Photo Picker
- EXIF metadata extraction (GPS, timestamp, camera/lens info)
- Auto-populate location and timestamp from photo metadata
- Weather fetch for photo's time and location
- Photo copied to `_attachments/photos/` in vault
- Obsidian embedding with `![[photos/filename.jpg]]` syntax
- Photo thumbnails in entry list (optimized loading)
- Hero zoom transition to fullscreen using native Quick Look
- Full Quick Look UI (share, markup, Done button)

---

## Original Planning Document

## Overview

Add a new entry type called "Photo" that allows users to import a single photo from their iOS photo library. The photo will be copied into the vault's `_attachments/photos/` folder, and its EXIF metadata (location, timestamp, camera info) will be automatically extracted and used to populate entry fields.

## User Requirements

- **Single photo per entry**: Each photo entry contains exactly one image
- **iOS Photo Picker integration**: Use native `PhotosPicker` to select images
- **Copy to vault**: Photo is copied to `_attachments/photos/` for vault portability
- **EXIF metadata extraction**: Automatically extract and use:
  - GPS location (latitude/longitude) → entry location + place matching
  - Timestamp → entry creation date
  - Camera info (model, lens, focal length) → stored in entry metadata
- **Obsidian embedding**: Link photo using `![[photos/filename.jpg]]` syntax
- **Weather fetch**: Use photo timestamp + location to fetch historical weather
- **Consistent UX**: Follow same FAB menu pattern as Text/Audio/Workout entries

## Current State Analysis

### Existing Patterns to Follow

**Attachment Storage** (from AudioFileManager):
- Directory structure: `_attachments/{type}/{entry-filename}.{ext}`
- Atomic file operations using Swift actors
- Security-scoped bookmark access for vault
- Sidecar metadata files when needed (e.g., `.srt` for audio)

**Entry Creation Flow** (from AudioEntryViewModel):
- Metadata capture: location, weather, State of Mind
- File manager actors for thread-safe I/O
- Placeholder replacement pattern: `![[PLACEHOLDER]]` → `![[photos/filename.jpg]]`
- YAML frontmatter storage for attachment references

**iOS Pickers** (from PlacePickerView, LocationSearchView):
- Native iOS picker components
- Binding-based data flow
- Sheet presentation patterns

### What Doesn't Exist Yet

1. **PhotoPicker integration** - Need to import `PhotosUI` framework
2. **EXIF metadata extraction** - Need `CoreLocation`, `ImageIO` frameworks
3. **Photo file manager** - New actor similar to `AudioFileManager`
4. **Photo entry view model** - Similar to `AudioEntryViewModel`
5. **Photo entry view** - UI for photo entry creation
6. **Image import logic** - Copy from Photos library to vault

## Architecture Design

### Component Structure

```
Menu FAB (existing)
  └── Photo Entry button (NEW)
      → PhotoEntryView (NEW)
        → PhotoEntryViewModel (NEW)
          → PhotoFileManager (NEW - actor)
            → EXIF metadata extraction
            → File copy to _attachments/photos/
```

### Data Flow

1. **User selects photo** via `PhotosPicker`
2. **Extract EXIF metadata**:
   - GPS coordinates → `currentLocation`
   - Timestamp → `timestamp`
   - Camera model/lens/focal length → `cameraMetadata`
3. **Auto-populate entry**:
   - Set timestamp from EXIF
   - Set location from GPS coords
   - Find matching Place within 100m radius
   - Fetch weather for timestamp + location
4. **User can override** any auto-populated fields
5. **Save entry**:
   - Copy photo to `_attachments/photos/{entryID}.{ext}`
   - Generate thumbnail for preview (optional)
   - Create entry with photo link: `![[photos/{entryID}.jpg]]`
   - Store camera metadata in YAML frontmatter

### File Structure

**New Files:**
1. `JournalCompanion/Services/FileSystem/PhotoFileManager.swift` - Actor for photo I/O
2. `JournalCompanion/ViewModels/PhotoEntryViewModel.swift` - Photo entry state management
3. `JournalCompanion/Views/EntryCreation/PhotoEntryView.swift` - Photo entry UI
4. `JournalCompanion/Models/PhotoMetadata.swift` - Camera/EXIF data model (optional)

**Modified Files:**
1. `JournalCompanion/App/ContentView.swift` - Add Photo button to FAB menu
2. `JournalCompanion/Models/Entry.swift` - Add `photoAttachment` and `cameraMetadata` fields (optional)

## Implementation Plan

### Phase 1: Foundation - PhotoFileManager

**File:** `JournalCompanion/Services/FileSystem/PhotoFileManager.swift`

**Purpose:** Handle photo file I/O operations with thread safety.

**Key Methods:**
```swift
actor PhotoFileManager {
    let vaultURL: URL
    private let fileManager = FileManager.default

    // Create photos directory: _attachments/photos/
    func createPhotosDirectory() async throws -> URL

    // Copy photo from Photos library to vault
    func writePhoto(
        from sourceURL: URL,
        for entry: Entry,
        originalFilename: String
    ) async throws -> String

    // Delete photo attachment
    func deletePhoto(filename: String) async throws

    // Generate filename: {entryID}.{ext}
    private func generateFilename(for entry: Entry, extension: String) -> String
}
```

**Filename Convention:**
```
YYYYMMDDHHmm.jpg  (or .png, .heic)
```

**Directory:**
```
_attachments/photos/202501151430.jpg
```

### Phase 2: EXIF Metadata Extraction

**Location:** `PhotoEntryViewModel` helper methods

**Frameworks:**
- `import ImageIO` - For EXIF data extraction
- `import CoreLocation` - For GPS coordinates

**Key Code Pattern:**
```swift
func extractEXIFMetadata(from imageURL: URL) async -> PhotoEXIF? {
    guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
    else { return nil }

    var exif = PhotoEXIF()

    // Extract GPS coordinates
    if let gpsInfo = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
       let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
       let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
       let latRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
       let lonRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String {
        let lat = latRef == "N" ? latitude : -latitude
        let lon = lonRef == "E" ? longitude : -longitude
        exif.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // Extract timestamp
    if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
       let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
        // Parse EXIF date format: "YYYY:MM:DD HH:mm:ss"
        exif.timestamp = parseEXIFDate(dateString)
    }

    // Extract camera info
    if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
        exif.cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
    }
    if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
        exif.lensModel = exifDict[kCGImagePropertyExifLensModel as String] as? String
        exif.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
    }

    return exif
}

struct PhotoEXIF {
    var location: CLLocationCoordinate2D?
    var timestamp: Date?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: Double?
}
```

### Phase 3: PhotoEntryViewModel

**File:** `JournalCompanion/ViewModels/PhotoEntryViewModel.swift`

**Pattern:** Mirror `AudioEntryViewModel` structure, adapt for photo.

**Core Properties:**
```swift
@MainActor
class PhotoEntryViewModel: ObservableObject {
    let vaultManager: VaultManager
    private let locationService: LocationService
    private let weatherService = WeatherService()
    private lazy var healthKitService = HealthKitService()

    // Photo selection
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var photoImage: UIImage?
    @Published var photoData: Data?
    @Published var photoEXIF: PhotoEXIF?

    // Location & Weather (auto-populated from EXIF)
    @Published var currentLocation: CLLocation?
    @Published var weatherData: WeatherData?
    @Published var isFetchingWeather: Bool = false

    // State of Mind
    @Published var moodData: StateOfMindData?
    @Published var showStateOfMindPicker: Bool = false
    @Published var tempMoodValence: Double = 0.0
    @Published var tempMoodLabels: [HKStateOfMind.Label] = []
    @Published var tempMoodAssociations: [HKStateOfMind.Association] = []

    // Entry metadata (timestamp from EXIF)
    @Published var timestamp: Date = Date()
    @Published var tags: [String] = ["entry", "iPhone", "photo_entry"]
    @Published var selectedPlace: Place?
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccess: Bool = false

    var isValid: Bool { photoData != nil }
}
```

**Key Methods:**
```swift
// Handle photo selection
func handlePhotoSelection(_ item: PhotosPickerItem) async {
    // Load photo data
    guard let data = try? await item.loadTransferable(type: Data.self),
          let image = UIImage(data: data) else { return }

    photoData = data
    photoImage = image

    // Extract EXIF metadata
    if let tempURL = saveTempFile(data: data),
       let exif = await extractEXIFMetadata(from: tempURL) {
        photoEXIF = exif

        // Auto-populate timestamp from EXIF
        if let exifTimestamp = exif.timestamp {
            timestamp = exifTimestamp
        }

        // Auto-populate location from GPS
        if let coords = exif.location {
            currentLocation = CLLocation(latitude: coords.latitude, longitude: coords.longitude)

            // Try to match nearby place
            selectedPlace = findMatchingPlace(for: currentLocation!)

            // Fetch weather for photo's timestamp and location
            await fetchWeather(for: currentLocation!, date: timestamp)
        }
    }
}

// Create and save photo entry
func createEntry() async {
    guard let photoData, let vaultURL = vaultManager.vaultURL else { return }

    isCreating = true
    defer { isCreating = false }

    do {
        // Determine file extension from photo data
        let ext = determineExtension(from: photoData) // .jpg, .png, .heic

        // Build entry with placeholder
        let content = "![[PHOTO_PLACEHOLDER]]"

        // Create entry
        var entry = Entry(
            id: UUID().uuidString,
            dateCreated: timestamp,
            tags: tags,
            place: selectedPlace?.name,
            location: formatLocation(currentLocation),
            content: content,
            temperature: weatherData?.temperature,
            condition: weatherData?.condition,
            humidity: weatherData?.humidity,
            aqi: weatherData?.aqi,
            // Camera metadata (optional new fields)
            cameraModel: photoEXIF?.cameraModel,
            lensModel: photoEXIF?.lensModel,
            focalLength: photoEXIF?.focalLength
        )

        // Add mood data if available
        if let mood = moodData {
            entry.moodValence = mood.valence
            entry.moodLabels = mood.labels
            entry.moodAssociations = mood.associations
        }

        // Save photo file
        let photoFileManager = PhotoFileManager(vaultURL: vaultURL)
        let tempURL = saveTempFile(data: photoData)!
        let filename = try await photoFileManager.writePhoto(
            from: tempURL,
            for: entry,
            extension: ext
        )

        // Replace placeholder with actual filename
        entry.content = entry.content.replacingOccurrences(
            of: "![[PHOTO_PLACEHOLDER]]",
            with: "![[photos/\(filename)]]"
        )

        // Store photo filename in entry (optional)
        entry.photoAttachment = filename

        // Write entry
        let writer = EntryWriter(vaultURL: vaultURL)
        try await writer.write(entry: entry)

        // Save State of Mind to HealthKit (non-fatal)
        if let mood = moodData {
            // ... same pattern as AudioEntryViewModel
        }

        showSuccess = true
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### Phase 4: PhotoEntryView

**File:** `JournalCompanion/Views/EntryCreation/PhotoEntryView.swift`

**UI Structure:**
```
NavigationStack
  Form
    Section "Photo"
      - If no photo: PhotosPicker button (large, centered)
      - If photo selected: Image preview + "Change Photo" button
      - Display camera metadata (read-only, if available)

    Section "Location"
      - Place picker button (auto-populated from EXIF GPS)
      - Show "Auto-detected from photo" hint if EXIF location used

    Section "Weather" (if available)
      - Auto-fetched weather display for photo's time + location
      - Refresh button if timestamp/location changed

    Section "State of Mind" (optional)
      - Mood picker button

    Section "Details"
      - Timestamp picker (auto-populated from EXIF)
      - Tags display

  Toolbar
    - Cancel (leading)
    - Save (trailing, disabled until photo selected)
```

**Key Code:**
```swift
struct PhotoEntryView: View {
    @StateObject var viewModel: PhotoEntryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showPlacePicker = false

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                locationSection
                weatherSection
                stateOfMindSection
                detailsSection
            }
            .navigationTitle("Photo Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .task {
            // No auto-detect location on appear - wait for photo EXIF
        }
        .onChange(of: viewModel.selectedPhoto) { _, newItem in
            if let item = newItem {
                Task {
                    await viewModel.handlePhotoSelection(item)
                }
            }
        }
        .onChange(of: viewModel.showSuccess) { _, success in
            if success { dismiss() }
        }
        // Sheet presentations for place picker, State of Mind, etc.
    }

    private var photoSection: some View {
        Section {
            if let image = viewModel.photoImage {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Label("Change Photo", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    // Camera metadata (if available)
                    if let exif = viewModel.photoEXIF {
                        VStack(alignment: .leading, spacing: 4) {
                            if let camera = exif.cameraModel {
                                Text("Camera: \(camera)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let lens = exif.lensModel {
                                Text("Lens: \(lens)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let focal = exif.focalLength {
                                Text("Focal Length: \(Int(focal))mm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        Text("Select Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Photo")
        } footer: {
            Text("Select a photo from your library. Location and time will be extracted from photo metadata.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Other sections follow AudioEntryView patterns...
}
```

### Phase 5: ContentView Integration

**File:** `JournalCompanion/App/ContentView.swift`

**Changes:**

1. **Add state variable:**
```swift
@State private var showPhotoEntry = false
```

2. **Add Photo button to Menu:**
```swift
Menu {
    Button {
        showQuickEntry = true
    } label: {
        Label("Text Entry", systemImage: "square.and.pencil")
    }

    Button {
        showAudioEntry = true
    } label: {
        Label("Audio Entry", systemImage: "waveform")
    }

    Button {
        showPhotoEntry = true  // NEW
    } label: {
        Label("Photo Entry", systemImage: "photo")  // NEW
    }

    Button {
        showWorkoutSync = true
    } label: {
        Label("Sync Workouts", systemImage: "figure.run")
    }
}
```

3. **Add PhotoEntryView sheet:**
```swift
.sheet(isPresented: $showPhotoEntry) {
    let viewModel = PhotoEntryViewModel(
        vaultManager: vaultManager,
        locationService: locationService
    )
    PhotoEntryView(viewModel: viewModel)
        .environmentObject(locationService)
        .environmentObject(templateManager)
}
.onChange(of: showPhotoEntry) { _, isShowing in
    if !isShowing {
        // Refresh entries when photo entry view closes
        Task {
            do {
                _ = try await vaultManager.loadEntries()
            } catch {
                print("❌ Failed to reload entries: \(error)")
            }
        }
    }
}
```

### Phase 6: Entry Model Updates (Optional)

**File:** `JournalCompanion/Models/Entry.swift`

**New optional fields for camera metadata:**
```swift
// Photo metadata (optional)
var photoAttachment: String?      // Filename in _attachments/photos/
var cameraModel: String?           // Camera model from EXIF
var lensModel: String?             // Lens model from EXIF
var focalLength: Double?           // Focal length in mm
```

**EntryReader updates:**
Parse new YAML fields:
```yaml
photo_attachment: "202501151430.jpg"
camera_model: "iPhone 17 Pro"
lens_model: "iPhone 17 Pro back camera 5.7mm f/1.78"
focal_length: 5.7
```

## Testing Checklist

### EXIF Extraction
- [x] GPS coordinates extracted correctly
- [x] Timestamp extracted and parsed correctly
- [x] Camera model/lens/focal length extracted
- [x] Handles photos without GPS data gracefully
- [x] Handles photos without timestamp gracefully

### Photo Import
- [x] Photo copied to `_attachments/photos/`
- [x] Filename format matches `{entryID}.{ext}`
- [x] Supports .jpg, .png, .heic formats
- [x] File permissions correct for vault access

### Auto-Population
- [x] Timestamp auto-fills from EXIF
- [x] Location auto-fills from GPS
- [x] Place auto-matched within 100m
- [x] Weather fetches for photo's time + location
- [x] User can override any auto-populated fields

### Entry Creation
- [x] Photo link embedded as `![[photos/filename.jpg]]`
- [x] Camera metadata stored in YAML
- [x] Entry appears in list with photo indicator
- [x] Photo displays correctly in entry detail view

### Edge Cases
- [x] Photo without EXIF data (manual entry required)
- [x] Photo with partial EXIF (missing GPS or timestamp)
- [ ] Large photo files (>10MB) - not tested
- [x] HEIC format conversion if needed

## Open Questions / Future Enhancements

1. **Thumbnail generation**: Should we generate thumbnails for list view performance?
2. **Image optimization**: Should large photos be compressed before import?
3. **Multiple photos**: Future enhancement to support photo galleries per entry?
4. **Photo editing**: Basic cropping/rotation before import?
5. **iCloud Photos**: Handle photos still in iCloud (not yet downloaded)?

---

# Feature 2: Configurable Folder Structure

## Overview

Make all vault folder paths user-configurable to support different Obsidian vault structures. Currently, all paths are hardcoded (e.g., `Entries/`, `Places/`, `_attachments/audio/`). Users need flexibility to match their existing vault organization.

## User Requirements

- **Settings-based configuration**: Accessible anytime in Settings view
- **Configure all paths**: Entries, People, Places, and all attachment types
- **Validation**: Ensure folders exist or can be created
- **Migration warnings**: Alert users if changing paths with existing data
- **Persistent storage**: Save configuration to UserDefaults
- **Backward compatibility**: Default to current hardcoded paths
- **Path preview**: Show full paths before saving

## Current State Analysis

### Hardcoded Path Locations

| Component | File | Line | Hardcoded Path |
|-----------|------|------|----------------|
| Entries directory | Entry.swift | 75-91 | `Entries/YYYY/MM-MMMM/DD/` |
| Days directory | EntryWriter.swift | 246 | `Days/YYYY/MM-MMMM/` |
| Places directory | PlaceWriter.swift | 27 | `Places/` |
| People directory | PersonWriter.swift | 27 | `People/` |
| Audio attachments | AudioFileManager.swift | 228 | `_attachments/audio/` |
| Routes (GPX) | GPXWriter.swift | 29-31 | `_attachments/routes/` |
| Maps | EntryWriter.swift | 161 | `_attachments/maps/` |

### Configuration Gap

**What exists:**
- Template management settings (PlaceTemplateSettingsView, PersonTemplateSettingsView)
- Vault root URL selection (VaultManager)

**What doesn't exist:**
- Path configuration storage
- Settings UI for folder paths
- Path validation logic
- Migration handling

## Architecture Design

### Configuration Model

**New File:** `JournalCompanion/Models/VaultConfiguration.swift`

```swift
struct VaultConfiguration: Codable {
    // Entry paths
    var entriesDirectory: String = "Entries"
    var daysDirectory: String = "Days"

    // Entity paths
    var placesDirectory: String = "Places"
    var peopleDirectory: String = "People"

    // Attachment paths
    var attachmentsDirectory: String = "_attachments"
    var audioDirectory: String = "audio"         // Relative to attachments
    var photosDirectory: String = "photos"       // Relative to attachments
    var routesDirectory: String = "routes"       // Relative to attachments
    var mapsDirectory: String = "maps"           // Relative to attachments

    // Template presets
    static let `default` = VaultConfiguration()

    static let flatStructure = VaultConfiguration(
        entriesDirectory: "Journal",
        daysDirectory: "Journal/Daily",
        placesDirectory: "Journal/Places",
        peopleDirectory: "Journal/People",
        attachmentsDirectory: "Journal/Attachments"
    )

    // Full path builders
    func entryPath(for date: Date) -> String {
        let year = Calendar.current.component(.year, from: date)
        let month = Calendar.current.component(.month, from: date)
        let day = Calendar.current.component(.day, from: date)
        let monthName = DateFormatter().monthSymbols[month - 1]
        return "\(entriesDirectory)/\(year)/\(String(format: "%02d", month))-\(monthName)/\(String(format: "%02d", day))"
    }

    func audioAttachmentsPath() -> String {
        "\(attachmentsDirectory)/\(audioDirectory)"
    }

    func photoAttachmentsPath() -> String {
        "\(attachmentsDirectory)/\(photosDirectory)"
    }

    // ... similar for other paths
}
```

### Configuration Storage

**Modified File:** `JournalCompanion/Services/FileSystem/VaultManager.swift`

**New properties:**
```swift
@Published var vaultConfiguration: VaultConfiguration = .default
private let configKey = "vaultConfiguration"
```

**New methods:**
```swift
// Load configuration from UserDefaults
func loadConfiguration() {
    if let data = UserDefaults.standard.data(forKey: configKey),
       let config = try? JSONDecoder().decode(VaultConfiguration.self, from: data) {
        vaultConfiguration = config
    } else {
        vaultConfiguration = .default
    }
}

// Save configuration to UserDefaults
func saveConfiguration(_ config: VaultConfiguration) throws {
    let data = try JSONEncoder().encode(config)
    UserDefaults.standard.set(data, forKey: configKey)
    vaultConfiguration = config
}

// Validate that configured directories exist or can be created
func validateConfiguration(_ config: VaultConfiguration) async throws -> [String: Bool] {
    guard let vaultURL else { throw VaultError.noVaultConfigured }

    var validation: [String: Bool] = [:]

    // Check each directory
    validation["entries"] = directoryExistsOrCanCreate(path: config.entriesDirectory)
    validation["days"] = directoryExistsOrCanCreate(path: config.daysDirectory)
    validation["places"] = directoryExistsOrCanCreate(path: config.placesDirectory)
    validation["people"] = directoryExistsOrCanCreate(path: config.peopleDirectory)
    validation["attachments"] = directoryExistsOrCanCreate(path: config.attachmentsDirectory)

    return validation
}
```

### Settings UI

**New File:** `JournalCompanion/Views/Settings/FolderStructureSettingsView.swift`

```swift
struct FolderStructureSettingsView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var config: VaultConfiguration
    @State private var showValidation = false
    @State private var validationResults: [String: Bool] = [:]
    @State private var showMigrationWarning = false
    @State private var hasExistingData = false

    init(vaultManager: VaultManager) {
        _config = State(initialValue: vaultManager.vaultConfiguration)
    }

    var body: some View {
        Form {
            templateSection
            entriesSection
            entitiesSection
            attachmentsSection
            previewSection
            actionsSection
        }
        .navigationTitle("Folder Structure")
        .alert("Migration Warning", isPresented: $showMigrationWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Change Anyway", role: .destructive) {
                saveConfiguration()
            }
        } message: {
            Text("Changing folder paths won't move existing files. You may need to manually reorganize your vault.")
        }
    }

    private var templateSection: some View {
        Section {
            Button {
                config = .default
            } label: {
                HStack {
                    Text("Default Structure")
                    Spacer()
                    if config == .default {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }

            Button {
                config = .flatStructure
            } label: {
                HStack {
                    Text("Flat Structure")
                    Spacer()
                    if config == .flatStructure {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
        } header: {
            Text("Presets")
        } footer: {
            Text("Choose a preset or customize paths below")
        }
    }

    private var entriesSection: some View {
        Section("Entries") {
            HStack {
                Text("Entries")
                Spacer()
                TextField("Entries", text: $config.entriesDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Days")
                Spacer()
                TextField("Days", text: $config.daysDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var entitiesSection: some View {
        Section("Entities") {
            HStack {
                Text("Places")
                Spacer()
                TextField("Places", text: $config.placesDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("People")
                Spacer()
                TextField("People", text: $config.peopleDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var attachmentsSection: some View {
        Section("Attachments") {
            HStack {
                Text("Base Directory")
                Spacer()
                TextField("_attachments", text: $config.attachmentsDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Audio")
                Spacer()
                TextField("audio", text: $config.audioDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Photos")
                Spacer()
                TextField("photos", text: $config.photosDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Routes")
                Spacer()
                TextField("routes", text: $config.routesDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Maps")
                Spacer()
                TextField("maps", text: $config.mapsDirectory)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Full Paths:")
                    .font(.headline)

                Text("Entries: \(config.entryPath(for: Date()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Places: \(config.placesDirectory)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Audio: \(config.audioAttachmentsPath())")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Photos: \(config.photoAttachmentsPath())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Preview")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task {
                    do {
                        validationResults = try await vaultManager.validateConfiguration(config)
                        showValidation = true
                    } catch {
                        // Handle error
                    }
                }
            } label: {
                Label("Validate Paths", systemImage: "checkmark.circle")
            }

            Button {
                if hasExistingData {
                    showMigrationWarning = true
                } else {
                    saveConfiguration()
                }
            } label: {
                Label("Save Configuration", systemImage: "square.and.arrow.down")
            }
            .disabled(config == vaultManager.vaultConfiguration)
        }
    }

    private func saveConfiguration() {
        do {
            try vaultManager.saveConfiguration(config)
        } catch {
            // Handle error
        }
    }
}
```

### Writer/Reader Updates

**Strategy:** Replace all hardcoded path strings with configuration lookups.

**Example - EntryWriter.swift:**

**Before:**
```swift
let directoryURL = vaultURL.appendingPathComponent(entry.directoryPath)
```

**After:**
```swift
let config = vaultManager.vaultConfiguration
let directoryPath = config.entryPath(for: entry.dateCreated)
let directoryURL = vaultURL.appendingPathComponent(directoryPath)
```

**Files to update:**
1. `Entry.swift` - Replace `directoryPath` computed property with config-based version
2. `EntryWriter.swift` - Use config for entry and day paths
3. `EntryReader.swift` - Use config for loading entries
4. `PlaceWriter.swift` - Use config for places directory
5. `PersonWriter.swift` - Use config for people directory
6. `AudioFileManager.swift` - Use config for audio attachments path
7. `PhotoFileManager.swift` (NEW) - Use config for photos path
8. `GPXWriter.swift` - Use config for routes path
9. Map snapshot code - Use config for maps path

### VaultManager Dependency Injection

**Challenge:** Writers/Readers need access to configuration, but currently only have `vaultURL`.

**Solution:** Pass configuration through initializers or make it accessible via a shared singleton.

**Option 1: Pass config to initializers**
```swift
actor EntryWriter {
    let vaultURL: URL
    let configuration: VaultConfiguration

    init(vaultURL: URL, configuration: VaultConfiguration) {
        self.vaultURL = vaultURL
        self.configuration = configuration
    }
}
```

**Option 2: Shared configuration manager (simpler)**
```swift
// In VaultManager
static var shared: VaultManager?

// Writers/readers access config
VaultManager.shared?.vaultConfiguration ?? .default
```

## Implementation Plan

### Phase 1: Configuration Model & Storage

1. Create `VaultConfiguration.swift` with default paths
2. Add configuration storage to `VaultManager`
3. Add preset templates (default, flat structure)
4. Add configuration persistence (UserDefaults)

### Phase 2: Settings UI

1. Create `FolderStructureSettingsView.swift`
2. Add to main `SettingsView` navigation
3. Implement path validation
4. Add migration warning system
5. Show full path previews

### Phase 3: Writer/Reader Migration

**Critical Files to Update (in order):**

1. `Entry.swift` - Make directoryPath configuration-aware
2. `VaultManager.swift` - Add shared instance or config injection pattern
3. `EntryWriter.swift` - Replace hardcoded paths with config
4. `EntryReader.swift` - Use config for loading
5. `PlaceWriter.swift` - Use config for places
6. `PersonWriter.swift` - Use config for people
7. `AudioFileManager.swift` - Use config for audio
8. `GPXWriter.swift` - Use config for routes
9. Map snapshot generation - Use config for maps

### Phase 4: Testing & Validation

**Test Cases:**
- [ ] Default configuration loads correctly
- [ ] Configuration persists across app restarts
- [ ] Path validation catches invalid directories
- [ ] Entries save to configured location
- [ ] Places/People save to configured locations
- [ ] Attachments save to configured subdirectories
- [ ] Existing vault with default structure still works
- [ ] User can change configuration without data loss
- [ ] Migration warning appears when appropriate

### Phase 5: Documentation & Migration Guide

Create user-facing documentation:
- How to configure folder structure
- Common vault organization patterns
- Migration steps for existing vaults
- Troubleshooting path issues

## Edge Cases & Considerations

### Data Migration
- **No automatic migration**: App won't move existing files
- **User responsibility**: Users must manually reorganize vault if needed
- **Warning system**: Alert users that changing paths requires manual migration

### Path Validation
- **Check for conflicts**: Ensure paths don't overlap (e.g., Entries can't be inside Places)
- **Relative vs absolute**: All paths relative to vault root
- **Special characters**: Validate folder names don't contain invalid characters
- **Nested paths**: Support arbitrary nesting depth

### Backward Compatibility
- **Default configuration**: Matches current hardcoded paths exactly
- **Existing installs**: Load default config on first launch
- **No breaking changes**: Old vaults continue working without reconfiguration

### Performance
- **Configuration caching**: Don't reload from UserDefaults on every file operation
- **Singleton pattern**: Consider shared VaultManager instance for performance

## Testing Checklist

### Configuration Storage
- [ ] Default configuration loads on first launch
- [ ] Configuration persists across app restarts
- [ ] Preset templates apply correctly
- [ ] Custom paths save and load correctly

### Path Validation
- [ ] Valid paths pass validation
- [ ] Invalid characters rejected
- [ ] Overlapping paths detected
- [ ] Non-existent directories flagged

### File Operations
- [ ] Entries save to configured path
- [ ] Days file created in configured path
- [ ] Places save to configured path
- [ ] People save to configured path
- [ ] Audio attachments save to configured path
- [ ] Photo attachments save to configured path
- [ ] Routes save to configured path
- [ ] Maps save to configured path

### Migration
- [ ] Warning appears when changing paths with existing data
- [ ] Users can cancel configuration changes
- [ ] No data loss when configuration changes

## Open Questions / Future Enhancements

1. **Automatic migration**: Tool to move files to new paths automatically?
2. **Multi-vault support**: Support switching between multiple vaults with different configs?
3. **Export/import config**: Share configuration between devices?
4. **Path templates**: More sophisticated templating for entry paths (e.g., custom date formats)?
5. **Validation depth**: Should we scan vault and warn about existing content in new paths?

---

# Implementation Priority

## Status

1. **Photo Entry Type** (Feature 1) ✅ **COMPLETED** - December 22, 2025
   - Full implementation with EXIF extraction
   - Hero zoom fullscreen preview
   - Photo thumbnails in list view

2. **Configurable Folder Structure** (Feature 2) - **NEXT**
   - More complex, touches many files
   - Critical for app distribution/public release

## Pre-Distribution Checklist

Before releasing the app publicly:
- [x] Photo entry feature complete and tested
- [ ] Folder structure configuration complete and tested
- [ ] User documentation created
- [ ] Migration guide for different vault structures
- [ ] App Store screenshots with various entry types
- [ ] Privacy policy for photo/location access
- [ ] TestFlight beta testing with diverse vault structures

---

*End of Roadmap*
