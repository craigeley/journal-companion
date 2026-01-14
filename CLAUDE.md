# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JournalCompanion is an iOS SwiftUI app that interfaces with an Obsidian vault (markdown files) for journaling. It reads/writes journal entries and place files, integrating location services, MapKit, and WeatherKit.

## Build & Run

```bash
# Build for simulator
xcodebuild -scheme JournalCompanion -destination 'platform=iOS Simulator,name=iPhone 17' build

# Clean build
xcodebuild -scheme JournalCompanion -destination 'platform=iOS Simulator,name=iPhone 17' clean build

# Run tests
xcodebuild -scheme JournalCompanion -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**JournalingSuggestions Framework:**
- JournalingSuggestions is only available on physical iOS devices (not simulators)
- Use `#if canImport(JournalingSuggestions)` to conditionally compile features that use this framework
- Pattern used in QuickEntryViewModel and QuickEntryView for suggestion functionality
- The app builds cleanly on both simulators and devices with this approach

## Architecture

### Data Flow Pattern: Vault → Manager → ViewModel → View

The app follows a unidirectional data flow centered around the **VaultManager** (the single source of truth):

```
Obsidian Vault (Markdown Files)
    ↓ (read/write via security-scoped bookmarks)
VaultManager (@Published properties)
    ↓ (injected as @EnvironmentObject)
ViewModels (@ObservableObject with Combine pipelines)
    ↓ (injected as @StateObject)
Views (SwiftUI)
```

### Key Architectural Patterns

**1. Vault as Single Source of Truth**
- VaultManager manages the Obsidian vault folder (markdown files on disk)
- Uses security-scoped bookmarks for persistent file access
- All data changes write to disk immediately (no in-memory database)
- Publishes `@Published var places: [Place]` and entries on demand

**2. File I/O with Actors**
- All file writes use Swift actors (e.g., `PlaceWriter`, `EntryWriter`)
- Ensures thread-safe, atomic file operations
- Pattern: `actor XWriter { func write/update(item: X) async throws }`

**3. Reactive Filtering with Combine**
- ViewModels use Combine pipelines to reactively filter/transform data
- Pattern: `vaultManager.$places.map { /* filter */ }.sink { /* update */ }`
- Common use: MapViewModel filters places by coordinates, then by user-selected types/tags
- Debouncing: Use `.debounce(for: .milliseconds(100), scheduler: RunLoop.main)` for rapid updates

**4. MVVM with Strict Separation**
- ViewModels are `@MainActor class X: ObservableObject`
- Views inject ViewModels as `@StateObject var viewModel: XViewModel`
- ViewModels handle business logic; Views are pure UI
- Pattern for multi-step flows: Use intermediate state in parent (e.g., ContentView coordinates location-first place creation)

### File Structure & Naming

**Markdown File Formats:**

*Entries:* `Entries/YYYY/MM-Month/DD/YYYYMMDDHHmm.md`
```markdown
---
date_created: 2025-01-15T14:30:00.000-08:00
tags: [journal, personal]
place: "[[Central Park]]"
place_callout: park
temperature: 72
condition: clear
---
Entry body content here.
```

*Places:* `Places/{sanitized-name}.md`
```markdown
---
location: 37.7749,-122.4194
addr: 123 Main St, San Francisco, CA
tags: [favorite, outdoor]
callout: cafe
aliases: [Blue Bottle, BB Coffee]
---
Optional place notes here.
```

**Filename Sanitization:**
- Entries: Use `YYYYMMDDHHmm` format (e.g., `202501151430.md`)
- Places: Use `Place.sanitizeFilename()` which removes `[<>:"\/\\|?*]` and normalizes whitespace
- Both formats match Ruby scripts used in the Obsidian vault

### Critical Data Models

**Entry** (`Models/Entry.swift`)
- `id`: Filename without extension
- `dateCreated`: Date (used for folder hierarchy)
- `place`: Optional place reference (stored as `[[Place Name]]` in markdown)
- `placeCallout`: Optional place type (cafe, park, etc.)
- Weather fields: `temperature`, `condition`, `aqi`, `humidity`

**Place** (`Models/Place.swift`)
- `id`: Sanitized filename without .md
- `location`: Optional `CLLocationCoordinate2D`
- `callout`: Type string (20 types: place, cafe, restaurant, park, school, home, shop, grocery, bar, medical, airport, hotel, library, zoo, museum, workout, concert, movie, entertainment, service)
- `tags`: Array of user-defined strings
- `content`: Body text after YAML frontmatter

### State Management Anti-Patterns to Avoid

**Publishing Changes During View Updates:**
```swift
// BAD - causes "Publishing changes from within view updates" error
var isValid: Bool {
    if placeName.isEmpty {
        nameError = "Required"  // Modifying @Published during render!
        return false
    }
    return true
}

// GOOD - pure computed property
var isValid: Bool {
    !placeName.isEmpty
}

// Separate method for side effects
func validateName() {
    nameError = placeName.isEmpty ? "Required" : nil
}
```

**Sheet Presentation Race Conditions:**
```swift
// BAD - can show blank sheet
@State var selectedPlace: Place?
@State var showSheet = false
// ... tap sets both separately

// GOOD - atomic presentation
@State var selectedPlace: Place?
.sheet(item: $selectedPlace) { place in
    DetailView(place: place)
}
```

### Location & MapKit Integration

**LocationSearchView Pattern:**
- Uses `MKLocalSearchCompleter` for real-time autocomplete
- Returns data via `@Binding` parameters: `selectedLocationName`, `selectedAddress`, `selectedCoordinates`
- iOS 26 API: Use `mapItem.location.coordinate` (not deprecated `mapItem.placemark.coordinate`)

**PlaceIcon System:**
- `PlaceIconProvider.swift` maps callout types → SF Symbols + Colors
- Always use `PlaceIcon.systemName(for:)` and `PlaceIcon.color(for:)` for consistency
- Used in: MapView pins, PlaceCreationView, MapFilterView

### Common Patterns

**Two-Step Flows (e.g., Place Creation):**
1. Parent view manages intermediate state: `@State private var pendingLocationName: String?`
2. First sheet (LocationSearchView) updates pending state via bindings
3. `onChange` detects first sheet dismiss → opens second sheet with pre-populated ViewModel
4. ViewModel accepts optional `initial*` parameters for pre-population

**Form Validation:**
- Computed `var isValid: Bool` for button enabling (pure, no side effects)
- Separate `func validateX()` for updating error messages
- Call `validateX()` in `.onChange(of: field)` modifiers

**Context-Aware FAB:**
```swift
if selectedTab == 0 {
    // Entries tab action
} else {
    // Places/Map tab action (tabs 1 & 2 share behavior)
}
```

### Git Branching (Gitflow)

This project uses the **Gitflow** branching model. Before starting work on a major feature or significant change:

1. **Check the working tree**: Run `git status` to verify the current branch and ensure a clean state
2. **Ask about branching**: For non-trivial features, ask the user if a new feature branch should be created

**Branch types:**
- `main` — Production-ready code; all commits should be tagged releases
- `develop` — Integration branch for completed features (upcoming release)
- `feature/*` — New functionality (branch from `develop`)
- `bugfix/*` — Non-critical fixes (branch from `develop`)
- `release/*` — Release preparation; refinements only, no new features
- `hotfix/*` — Urgent production fixes (branch from `main`)

**Workflow for features:**
```bash
# Create a feature branch
git checkout develop
git checkout -b feature/descriptive-name

# When complete, merge back to develop
git checkout develop
git merge --no-ff feature/descriptive-name
```

### Git Commit Messages

Use structured commit messages with emoji:
```
Add [feature]: Brief description

Detailed explanation of what/why.

Implementation:
- Bullet points
- Of key changes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### SwiftUI Concurrency Notes

- All ViewModels are `@MainActor` (Swift 6 strict concurrency)
- Actors for file I/O must use `await MainActor.run { }` to access MainActor-isolated properties
- Use `.sink { [weak self] in }` in Combine to avoid retain cycles
- Store cancellables: `private var cancellables = Set<AnyCancellable>()`
