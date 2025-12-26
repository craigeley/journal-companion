# JournalCompanion Watch App Plan

## Overview

Build a watchOS companion app focused on quick "check-ins" - logging time and location with an optional note. The watch app serves as a lightweight capture tool; full entry editing happens on iPhone.

---

## Core Feature: Quick Check-In

### User Experience
1. User opens watch app → sees a large "+" button
2. Tap "+" → immediately captures current time & location
3. Optional: Enter a quick note via dictation or scribble
4. Tap "Done" → saves entry to vault
5. Entry syncs to iPhone where user can add more details later

### Entry Format
Check-ins create standard Entry files with minimal metadata:
```yaml
---
date_created: 2025-01-15T14:30:00.000-08:00
tags:
  - checkin
  - watch
location: 37.7749,-122.4194
place: "[[Matched Place Name]]"  # if within 100m of known place
---
Optional quick note here.
```

---

## Architecture

### Project Structure

```
JournalCompanion/
├── JournalCompanion/              # Existing iOS app
├── JournalCompanionWatch/         # New watchOS app
│   ├── App/
│   │   └── JournalCompanionWatchApp.swift
│   ├── Views/
│   │   ├── CheckInView.swift          # Main view with "+" button
│   │   ├── QuickNoteInputView.swift   # Note entry (dictation/scribble)
│   │   ├── CheckInConfirmationView.swift  # Success feedback
│   │   └── RecentCheckInsView.swift   # Optional: view recent entries
│   ├── ViewModels/
│   │   └── CheckInViewModel.swift     # Handles check-in logic
│   └── Services/
│       └── WatchLocationService.swift # Watch-optimized location
├── Shared/                        # Shared code (new framework)
│   ├── Models/
│   │   ├── Entry.swift            # Move from iOS
│   │   └── Place.swift            # Move from iOS
│   └── Services/
│       ├── EntryWriter.swift      # Move from iOS
│       └── PlaceMatcher.swift     # Move from iOS
└── JournalCompanionWatch.xcodeproj  # Or add to existing project
```

### Data Sync Strategy

**Option A: WatchConnectivity (Recommended for MVP)**
- Watch sends check-in data to iPhone via `WCSession`
- iPhone's VaultManager writes to vault
- Pros: Simple, reliable, works offline
- Cons: Requires iPhone nearby for sync

**Option B: Shared iCloud Container**
- Both apps access same iCloud container
- Watch writes directly to vault files
- Pros: True independence from iPhone
- Cons: Complex security-scoped bookmark handling on watch

**Recommendation**: Start with Option A for MVP, evolve to Option B if needed.

---

## Implementation Phases

### Phase 1: Project Setup
- [ ] Create watchOS target in Xcode project
- [ ] Set up basic app structure with SwiftUI
- [ ] Configure WatchConnectivity between iOS and watchOS
- [ ] Add shared framework for common models

### Phase 2: Core Check-In Feature
- [ ] Implement CheckInView with large "+" button
- [ ] Implement WatchLocationService for GPS
- [ ] Create CheckInViewModel to coordinate capture
- [ ] Build QuickNoteInputView with dictation support
- [ ] Add haptic feedback for successful check-in

### Phase 3: iOS Integration
- [ ] Add WatchConnectivity handling to iOS app
- [ ] Create WatchSyncService on iOS to receive check-ins
- [ ] Write received check-ins to vault via EntryWriter
- [ ] Update EntryListViewModel to show watch entries

### Phase 4: Enhanced Features (Optional)
- [ ] Add RecentCheckInsView to see last few entries
- [ ] Add complication for quick access from watch face
- [ ] Add weather data to check-ins (WeatherKit works on watch)
- [ ] Add place matching for nearby known places

---

## Detailed Component Specifications

### 1. CheckInView.swift

Main interface with prominent check-in button:

```swift
struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()

    var body: some View {
        VStack {
            // Status indicator (location accuracy, sync status)
            StatusBadge(status: viewModel.locationStatus)

            Spacer()

            // Large check-in button
            Button(action: viewModel.startCheckIn) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            Text("Check In")
                .font(.headline)

            Spacer()

            // Recent check-ins count
            Text("\(viewModel.todayCount) today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $viewModel.showNoteInput) {
            QuickNoteInputView(viewModel: viewModel)
        }
    }
}
```

### 2. CheckInViewModel.swift

Coordinates the check-in flow:

```swift
@MainActor
class CheckInViewModel: ObservableObject {
    @Published var locationStatus: LocationStatus = .unknown
    @Published var showNoteInput = false
    @Published var isProcessing = false
    @Published var todayCount = 0

    private let locationService = WatchLocationService()
    private let connectivity = WatchConnectivityManager.shared

    private var capturedLocation: CLLocation?
    private var capturedTime: Date?

    func startCheckIn() {
        isProcessing = true
        capturedTime = Date()

        Task {
            // Capture location
            capturedLocation = await locationService.getCurrentLocation()

            // Show note input (user can skip)
            showNoteInput = true
            isProcessing = false
        }
    }

    func completeCheckIn(note: String?) {
        guard let time = capturedTime else { return }

        let checkIn = CheckInData(
            timestamp: time,
            location: capturedLocation?.coordinate,
            note: note
        )

        // Send to iPhone
        connectivity.sendCheckIn(checkIn)

        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // Reset state
        showNoteInput = false
        capturedLocation = nil
        capturedTime = nil
        todayCount += 1
    }

    func skipNote() {
        completeCheckIn(note: nil)
    }
}
```

### 3. QuickNoteInputView.swift

Simple note entry with dictation:

```swift
struct QuickNoteInputView: View {
    @ObservedObject var viewModel: CheckInViewModel
    @State private var noteText = ""

    var body: some View {
        VStack {
            // Location confirmation
            if let loc = viewModel.capturedLocation {
                Label("Location captured", systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            // Note input (supports dictation automatically)
            TextField("Add a note...", text: $noteText)
                .textContentType(.none)

            HStack {
                Button("Skip") {
                    viewModel.skipNote()
                }
                .foregroundColor(.secondary)

                Button("Done") {
                    viewModel.completeCheckIn(note: noteText.isEmpty ? nil : noteText)
                }
                .foregroundColor(.blue)
            }
        }
    }
}
```

### 4. WatchConnectivityManager.swift

Handles iPhone ↔ Watch communication:

```swift
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var pendingCheckIns: [CheckInData] = []

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendCheckIn(_ checkIn: CheckInData) {
        guard let session = session else { return }

        let message: [String: Any] = [
            "type": "checkIn",
            "timestamp": checkIn.timestamp.timeIntervalSince1970,
            "latitude": checkIn.location?.latitude ?? 0,
            "longitude": checkIn.location?.longitude ?? 0,
            "hasLocation": checkIn.location != nil,
            "note": checkIn.note ?? ""
        ]

        if session.isReachable {
            // Send immediately
            session.sendMessage(message, replyHandler: nil)
        } else {
            // Queue for later
            session.transferUserInfo(message)
        }
    }

    // WCSessionDelegate methods...
}
```

### 5. iOS Side: WatchSyncService.swift

Receives and processes check-ins on iPhone:

```swift
@MainActor
class WatchSyncService: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    private var session: WCSession?
    private var vaultManager: VaultManager?

    func configure(vaultManager: VaultManager) {
        self.vaultManager = vaultManager

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            await processCheckIn(message)
        }
    }

    private func processCheckIn(_ message: [String: Any]) async {
        guard let vaultManager = vaultManager,
              let timestamp = message["timestamp"] as? TimeInterval else { return }

        let date = Date(timeIntervalSince1970: timestamp)
        let note = message["note"] as? String ?? ""
        let hasLocation = message["hasLocation"] as? Bool ?? false

        var entry = Entry(dateCreated: date)
        entry.content = note
        entry.tags = ["checkin", "watch"]

        if hasLocation,
           let lat = message["latitude"] as? Double,
           let lon = message["longitude"] as? Double {
            entry.location = "\(lat),\(lon)"

            // Match to known place
            if let place = await matchPlace(lat: lat, lon: lon) {
                entry.place = "[[" + place.name + "]]"
                entry.placeCallout = place.callout
            }
        }

        // Write to vault
        let writer = EntryWriter(vaultURL: vaultManager.vaultURL!)
        try? await writer.write(entry)

        // Refresh entries
        await vaultManager.loadEntries()
    }
}
```

---

## UI/UX Considerations

### Watch Interface Guidelines
- **Large touch targets**: "+" button should be at least 44pt diameter
- **Minimal text**: Use icons and brief labels
- **Quick interactions**: Entire check-in should take <5 seconds
- **Clear feedback**: Haptic confirmation on success
- **Offline support**: Queue check-ins when iPhone unreachable

### Visual Design
- Match iOS app's color scheme and iconography
- Use SF Symbols consistently (plus.circle.fill for check-in)
- Show location/sync status subtly (small badge or icon)
- Success state: Brief checkmark animation

### Complications
Add a complication for instant access:
- **Graphic Circular**: "+" icon, tap to open app
- **Graphic Corner**: Small icon + today's count
- **Modular Small**: Count of today's check-ins

---

## Technical Considerations

### Location on Apple Watch
- Watch uses iPhone's GPS when paired and nearby
- Falls back to less accurate location when standalone
- Request "When In Use" permission (simpler than "Always")
- Handle location unavailable gracefully

### Battery Efficiency
- Don't continuously track location
- Only request location when user taps check-in
- Use low-accuracy location if high accuracy takes too long
- Timeout after 10 seconds, use last known location

### Offline Handling
- Store pending check-ins in UserDefaults or local file
- Sync when WCSession becomes reachable
- Show pending count in UI
- Don't lose data if app is killed

### Security
- Check-in data contains location (sensitive)
- Use WatchConnectivity's secure channel
- Don't log coordinates in production
- Respect user's location privacy settings

---

## Testing Strategy

### Unit Tests
- CheckInViewModel state management
- Location capture flow
- WatchConnectivity message formatting
- Entry creation from check-in data

### Integration Tests
- End-to-end: Watch check-in → iPhone vault file
- Offline queueing and sync
- Place matching accuracy

### Manual Testing
- Real device testing required (simulator limited)
- Test with iPhone nearby and standalone
- Test in various locations
- Test with poor GPS signal

---

## Future Enhancements

### Post-MVP Features
1. **Complications**: Quick access from watch face
2. **Recent entries**: View last 5-10 check-ins on watch
3. **Weather capture**: Include conditions in check-in
4. **Workout integration**: Auto-log workouts as entries
5. **Quick actions**: Pre-defined note templates ("Coffee", "Meeting", etc.)
6. **Voice notes**: Record short audio clips

### Advanced Features
1. **Direct iCloud sync**: Write to vault without iPhone
2. **Apple Watch Ultra**: Extended GPS tracking for hikes
3. **Siri integration**: "Hey Siri, check in to my journal"
4. **Focus modes**: Different behavior based on Focus

---

## Dependencies & Requirements

### Minimum Requirements
- watchOS 10+ (matches iOS 18+ requirement)
- iPhone paired and Watch app installed
- Location permission granted on watch
- Vault configured on iPhone

### Frameworks
- SwiftUI (watch UI)
- WatchConnectivity (iOS ↔ watchOS sync)
- CoreLocation (GPS)
- WatchKit (haptics, complications)

### Xcode Configuration
- Add watchOS target to existing project
- Share code via framework target or file references
- Configure App Group for shared UserDefaults (if needed)
- Set up WatchConnectivity entitlements

---

## Estimated Effort

### Phase 1: Project Setup
- Create watchOS target and configure build settings
- Set up WatchConnectivity on both sides
- Create shared framework for models

### Phase 2: Core Check-In
- CheckInView with button UI
- Location service implementation
- QuickNoteInputView with dictation
- CheckInViewModel coordination

### Phase 3: iOS Integration
- WatchSyncService implementation
- Entry writing from check-in data
- Place matching integration
- UI updates for watch entries

### Phase 4: Polish
- Haptic feedback
- Error handling and offline support
- Complication implementation
- Testing and bug fixes

---

## Files to Create

```
JournalCompanionWatch/
├── App/
│   └── JournalCompanionWatchApp.swift
├── Views/
│   ├── CheckInView.swift
│   ├── QuickNoteInputView.swift
│   └── CheckInConfirmationView.swift
├── ViewModels/
│   └── CheckInViewModel.swift
├── Services/
│   ├── WatchLocationService.swift
│   └── WatchConnectivityManager.swift
└── Models/
    └── CheckInData.swift

# iOS additions:
JournalCompanion/Services/
└── WatchSyncService.swift
```

---

## Summary

This plan creates a focused, minimal watch app that excels at one thing: quick location check-ins. The architecture leverages existing iOS code where possible, uses WatchConnectivity for reliable syncing, and follows watchOS design patterns for a native experience.

The key insight is that the watch app doesn't need to be a full journal - it's a capture tool. Full editing, browsing, and organization happen on iPhone. This constraint keeps the watch experience fast and focused.
