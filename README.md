# JournalCompanion

An iOS app for contextual journaling that integrates with an Obsidian vault. Capture journal entries enriched with location, weather, audio, photos, and health data—all stored as markdown files.

## Features

### Multi-Type Journal Entries
- **Text Entries** - Quick journaling with location, weather, and mood capture
- **Audio Entries** - Voice recording with automatic speech transcription
- **Photo Entries** - Photo-based journaling with EXIF metadata extraction
- **Workout Entries** - HealthKit integration for syncing runs, cycles, and workouts with GPS routes

### Place Management
Track locations with 20 place types (cafe, restaurant, park, home, etc.). Each place stores coordinates, address, tags, aliases, and custom icons. Places are referenced in entries via wiki-link syntax `[[Place Name]]`.

### Media Library
Track movies, TV shows, books, podcasts, and albums with iTunes Search integration for metadata lookup.

### People
Maintain a contact database with relationship types, contact info, birthdays, and notes. Reference people in entries with wiki-links.

### Interactive Map
MapKit-based map displaying all saved places with filtering by type and tags.

### Weather Integration
WeatherKit integration captures temperature, conditions, humidity, and air quality for each entry.

### Health Data
HealthKit integration for workout sync including distance, pace, heart rate, running metrics, and State of Mind mood tracking.

### Universal Search
Search across entries, places, people, and media from a unified interface.

## Architecture

The app follows a unidirectional data flow pattern:

```
Obsidian Vault (Markdown Files)
    ↓
VaultManager (Single Source of Truth)
    ↓
ViewModels (Combine-based reactive pipelines)
    ↓
SwiftUI Views
```

### Key Patterns
- **Security-scoped bookmarks** for persistent vault access
- **Swift Actors** for thread-safe file I/O
- **Combine pipelines** for reactive filtering and data transformation
- **MVVM** with strict separation of concerns

## Technologies

- SwiftUI
- Combine
- MapKit
- WeatherKit
- HealthKit
- CoreLocation
- AVFoundation
- Speech Framework
- PhotosUI

## File Structure

The app reads and writes markdown files to an Obsidian vault:

```
Vault/
├── Entries/
│   └── YYYY/MM-Month/DD/YYYYMMDDHHmm.md
├── Places/
│   └── {place-name}.md
├── People/
│   └── {person-name}.md
└── Media/
    └── {title}.md
```

Each file uses YAML frontmatter for structured metadata.

## Requirements

- iOS 17.0+
- Xcode 16+
- An Obsidian vault accessible via Files app

## Building

```bash
# Build for simulator
xcodebuild -scheme JournalCompanion -destination 'platform=iOS Simulator,name=iPhone 17' build

# Clean build
xcodebuild -scheme JournalCompanion -destination 'platform=iOS Simulator,name=iPhone 17' clean build

# Run tests
xcodebuild -scheme JournalCompanion -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**Note:** JournalingSuggestions framework features require a physical device and are conditionally compiled out for simulator builds.

## Setup

1. Build and run the app on your device
2. Grant requested permissions (Location, Health, Microphone, Photos)
3. Select your Obsidian vault folder when prompted
4. Start journaling

## License

Private project.
