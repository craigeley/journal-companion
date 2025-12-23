//
//  EntryDetailView.swift
//  JournalCompanion
//
//  Detail view for displaying entry information (read-only)
//

import SwiftUI
import QuickLook

struct EntryDetailView: View {
    let entry: Entry
    @EnvironmentObject var vaultManager: VaultManager
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var templateManager: TemplateManager
    @Environment(\.dismiss) var dismiss
    @State private var showEditView = false
    @State private var currentEntry: Entry
    @State private var showPlaybackView = false
    @State private var selectedAudioIndex: Int?
    @State private var showTranscriptEdit = false
    @State private var sourceImageView: UIView?
    @State private var quickLookPresenter = QuickLookPresenter()

    init(entry: Entry) {
        self.entry = entry
        _currentEntry = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            List {
                // Photo Section (if photo entry)
                if hasPhoto, let vaultURL = vaultManager.vaultURL, let photoFilename = currentEntry.photoAttachment {
                    Section("Photo") {
                        PhotoDetailImageView(
                            vaultURL: vaultURL,
                            filename: photoFilename,
                            sourceView: $sourceImageView
                        ) { url in
                            quickLookPresenter.present(url: url, sourceView: sourceImageView)
                        }
                    }
                }

                // Audio Section (if audio entry)
                if hasAudio {
                    Section("Audio Recording") {
                        ForEach(Array((currentEntry.audioAttachments ?? []).enumerated()), id: \.offset) { index, filename in
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Recording \(index + 1)")
                                            .font(.subheadline)
                                        if let device = currentEntry.recordingDevice {
                                            Text(device)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        selectedAudioIndex = index
                                        showPlaybackView = true
                                    } label: {
                                        Image(systemName: "play.fill")
                                            .foregroundStyle(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Edit Transcript button
                                Button {
                                    selectedAudioIndex = index
                                    showTranscriptEdit = true
                                } label: {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Edit Transcript")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if let rate = currentEntry.sampleRate, let depth = currentEntry.bitDepth {
                            Text("\(rate)Hz • \(depth)-bit")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else if let rate = currentEntry.sampleRate {
                            Text("\(rate)Hz")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Running Section (if running entry)
                if currentEntry.isRunningEntry {
                    Section("Running Workout") {
                        if let vaultURL = vaultManager.vaultURL {
                            RunningDetailView(
                                entry: currentEntry,
                                vaultURL: vaultURL
                            )
                        } else {
                            Text("Unable to load running data")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Entry Content Section (read-only with rendered markdown + wiki-links, embeds removed)
                Section("Entry") {
                    MarkdownWikiText(
                        text: contentWithoutEmbeds,
                        places: vaultManager.places,
                        people: vaultManager.people,
                        lineLimit: nil,
                        font: .body
                    )
                }

                // Location Section (place wiki-links in content are also tappable)
                if let placeName = currentEntry.place {
                    Section("Location") {
                        if let place = vaultManager.places.first(where: { $0.name == placeName }) {
                            Text(place.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(placeName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // People Section removed - people now rendered inline as wiki-links in entry content

                // Details Section
                Section("Details") {
                    LabeledContent("Date") {
                        Text(currentEntry.dateCreated, style: .date)
                    }
                    LabeledContent("Time") {
                        Text(currentEntry.dateCreated, style: .time)
                    }

                    if !currentEntry.tags.isEmpty {
                        LabeledContent("Tags") {
                            Text(currentEntry.tags.joined(separator: ", "))
                                .font(.caption)
                        }
                    }
                }

                // Weather Section (if exists)
                if currentEntry.temperature != nil || currentEntry.condition != nil {
                    Section("Weather") {
                        if let temp = currentEntry.temperature {
                            LabeledContent("Temperature", value: "\(temp)°F")
                        }
                        if let condition = currentEntry.condition {
                            LabeledContent("Condition", value: condition)
                        }
                        if let humidity = currentEntry.humidity {
                            LabeledContent("Humidity", value: "\(humidity)%")
                        }
                        if let aqi = currentEntry.aqi {
                            LabeledContent("AQI", value: "\(aqi)")
                        }
                    }
                }
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showEditView = true
                    }
                }
            }
            .sheet(isPresented: $showEditView) {
                EntryEditView(viewModel: EntryEditViewModel(
                    entry: currentEntry,
                    vaultManager: vaultManager,
                    locationService: locationService
                ))
            }
            .onChange(of: showEditView) { _, isShowing in
                if !isShowing {
                    // Reload entry when edit view closes
                    Task {
                        await reloadEntry()
                    }
                }
            }
            .sheet(isPresented: $showPlaybackView) {
                if let index = selectedAudioIndex,
                   let filename = currentEntry.audioAttachments?[safe: index],
                   let vaultURL = vaultManager.vaultURL {

                    let audioURL = vaultURL
                        .appendingPathComponent("_attachments")
                        .appendingPathComponent("audio")
                        .appendingPathComponent(filename)

                    // Get transcription from content (extract the segment after the audio embed)
                    let transcription = extractTranscription(for: index)

                    // Load time ranges from SRT sidecar file
                    AudioPlaybackContainerView(
                        audioURL: audioURL,
                        filename: filename,
                        transcription: transcription,
                        entry: currentEntry,
                        vaultURL: vaultURL
                    )
                }
            }
            .sheet(isPresented: $showTranscriptEdit) {
                if let index = selectedAudioIndex,
                   let filename = currentEntry.audioAttachments?[safe: index],
                   let vaultURL = vaultManager.vaultURL {

                    // Load time ranges from SRT and present edit view
                    TranscriptEditContainerView(
                        entry: currentEntry,
                        audioFilename: filename,
                        vaultURL: vaultURL,
                        vaultManager: vaultManager
                    )
                }
            }
            .onChange(of: showTranscriptEdit) { _, isShowing in
                if !isShowing {
                    // Reload entry when transcript edit view closes
                    Task {
                        await reloadEntry()
                    }
                }
            }
        }
    }

    private func reloadEntry() async {
        guard let vaultURL = vaultManager.vaultURL else { return }

        do {
            let reader = EntryReader(vaultURL: vaultURL)
            let allEntries = try await reader.loadEntries(limit: 100)

            // Find the updated entry by ID
            if let updatedEntry = allEntries.first(where: { $0.id == currentEntry.id }) {
                currentEntry = updatedEntry
            }
        } catch {
            print("❌ Failed to reload entry: \(error)")
        }
    }

    // MARK: - Entry Type Detection

    private var hasAudio: Bool {
        currentEntry.audioAttachments != nil && !(currentEntry.audioAttachments?.isEmpty ?? true)
    }

    private var hasPhoto: Bool {
        currentEntry.isPhotoEntry
    }

    private var contentWithoutEmbeds: String {
        var cleaned = currentEntry.content

        // Remove Obsidian audio embeds: ![[audio/filename.ext]]
        let audioEmbedPattern = #"!\[\[audio/[^\]]+\]\]"#
        if let regex = try? NSRegularExpression(pattern: audioEmbedPattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Remove Obsidian photo embeds: ![[photos/filename.ext]]
        let photoEmbedPattern = #"!\[\[photos/[^\]]+\]\]"#
        if let regex = try? NSRegularExpression(pattern: photoEmbedPattern, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: range,
                withTemplate: ""
            )
        }

        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract transcription text for a specific audio segment
    private func extractTranscription(for index: Int) -> String {
        // The transcription follows the audio embed in the content
        // Pattern: ![[audio/filename.ext]]\n\nTranscription text\n\n
        let components = currentEntry.content.components(separatedBy: "![[audio/")

        guard index + 1 < components.count else { return "" }

        // Get the section after the target audio embed
        let section = components[index + 1]

        // Extract text between the embed close and next embed or end
        if let closeIndex = section.firstIndex(of: "]"),
           let doubleNewline = section[closeIndex...].range(of: "\n\n") {
            let startIndex = doubleNewline.upperBound
            let remainingText = section[startIndex...]

            // Find next audio embed or end of text
            if let nextEmbed = remainingText.range(of: "![[audio/") {
                return String(remainingText[..<nextEmbed.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return String(remainingText).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ""
    }
}

// MARK: - Audio Playback Container

/// Container view that loads time ranges from SRT sidecar file before presenting playback
struct AudioPlaybackContainerView: View {
    let audioURL: URL
    let filename: String
    let transcription: String
    let entry: Entry
    let vaultURL: URL

    @State private var timeRanges: [TimeRange] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading audio...")
            } else {
                AudioPlaybackView(
                    audioURL: audioURL,
                    transcription: transcription,
                    timeRanges: timeRanges
                )
            }
        }
        .task {
            await loadTimeRanges()
        }
    }

    private func loadTimeRanges() async {
        let audioFileManager = AudioFileManager(vaultURL: vaultURL)

        do {
            timeRanges = try await audioFileManager.loadTimeRanges(
                for: filename,
                entry: entry
            )
            print("📖 Loaded \(timeRanges.count) time ranges from SRT file")
        } catch {
            print("⚠️ Failed to load time ranges: \(error)")
            timeRanges = []
        }

        isLoading = false
    }
}

// MARK: - Transcript Edit Container

/// Container view that loads time ranges from SRT before presenting transcript edit view
struct TranscriptEditContainerView: View {
    let entry: Entry
    let audioFilename: String
    let vaultURL: URL
    let vaultManager: VaultManager

    @State private var timeRanges: [TimeRange] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading transcript...")
            } else if timeRanges.isEmpty {
                ContentUnavailableView {
                    Label("No Transcript", systemImage: "text.bubble")
                } description: {
                    Text("This audio recording has no transcript data")
                }
            } else {
                TranscriptEditView(
                    viewModel: TranscriptEditViewModel(
                        entry: entry,
                        audioFilename: audioFilename,
                        timeRanges: timeRanges,
                        vaultManager: vaultManager
                    )
                )
            }
        }
        .task {
            await loadTimeRanges()
        }
    }

    private func loadTimeRanges() async {
        let audioFileManager = AudioFileManager(vaultURL: vaultURL)

        do {
            timeRanges = try await audioFileManager.loadTimeRanges(
                for: audioFilename,
                entry: entry
            )
            print("📖 Loaded \(timeRanges.count) time ranges for editing")
        } catch {
            print("⚠️ Failed to load time ranges for editing: \(error)")
            timeRanges = []
        }

        isLoading = false
    }
}

// MARK: - Photo Detail Image View

/// View for displaying a photo in entry detail with full size and camera metadata
struct PhotoDetailImageView: View {
    let vaultURL: URL
    let filename: String
    @Binding var sourceView: UIView?
    let onTap: (URL) -> Void

    @State private var image: UIImage?
    @State private var isLoading = true

    private var photoURL: URL {
        vaultURL
            .appendingPathComponent("_attachments")
            .appendingPathComponent("photos")
            .appendingPathComponent(filename)
    }

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(
                        SourceViewCapture(sourceView: $sourceView)
                    )
                    .onTapGesture {
                        onTap(photoURL)
                    }
            } else {
                ContentUnavailableView {
                    Label("Photo Not Found", systemImage: "photo")
                } description: {
                    Text(filename)
                }
                .frame(height: 200)
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        let url = photoURL  // Capture URL before detached task
        guard FileManager.default.fileExists(atPath: url.path) else {
            isLoading = false
            return
        }

        // Load image on background thread
        let loadedImage = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data) else {
                return nil as UIImage?
            }
            return uiImage
        }.value

        await MainActor.run {
            self.image = loadedImage
            self.isLoading = false
        }
    }
}

// MARK: - Source View Capture

/// Captures the underlying UIView for hero zoom transitions
struct SourceViewCapture: UIViewRepresentable {
    @Binding var sourceView: UIView?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            // Walk up to find the image view's superview that contains the actual rendered content
            if let superview = view.superview {
                sourceView = superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let superview = uiView.superview {
                sourceView = superview
            }
        }
    }
}

// MARK: - Quick Look Presenter

/// Presents QLPreviewController using UIKit's native presentation for proper hero zoom transitions
@MainActor
class QuickLookPresenter: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    private var url: URL?
    private weak var sourceView: UIView?

    func present(url: URL, sourceView: UIView?) {
        self.url = url
        self.sourceView = sourceView

        let previewController = QLPreviewController()
        // Set presentation style before accessing dataSource/delegate to avoid console warning
        previewController.modalPresentationStyle = .overFullScreen
        previewController.dataSource = self
        previewController.delegate = self

        // Find the topmost view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        topController.present(previewController, animated: true)
    }

    // MARK: - QLPreviewControllerDataSource

    nonisolated func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    nonisolated func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return MainActor.assumeIsolated {
            (url ?? URL(fileURLWithPath: "")) as QLPreviewItem
        }
    }

    // MARK: - QLPreviewControllerDelegate (Hero Zoom)

    nonisolated func previewController(_ controller: QLPreviewController, transitionViewFor item: any QLPreviewItem) -> UIView? {
        return MainActor.assumeIsolated {
            sourceView
        }
    }

    nonisolated func previewController(_ controller: QLPreviewController, frameFor item: any QLPreviewItem, inSourceView view: AutoreleasingUnsafeMutablePointer<UIView?>) -> CGRect {
        return MainActor.assumeIsolated {
            guard let sourceView = sourceView else {
                return .zero
            }
            view.pointee = sourceView
            return sourceView.bounds
        }
    }
}

// MARK: - Array Safe Subscript Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
