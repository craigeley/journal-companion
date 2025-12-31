import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Use coordinator to ensure we only present once
        guard !context.coordinator.didPresent else { return }

        // Small delay to ensure view is in window hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard !context.coordinator.didPresent,
                  uiViewController.view.window != nil else { return }

            context.coordinator.didPresent = true

            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )

            // For iPad support
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX,
                                           y: uiViewController.view.bounds.midY,
                                           width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            // Dismiss the sheet when activity controller is dismissed
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                context.coordinator.dismiss()
            }

            uiViewController.present(activityViewController, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator {
        var didPresent = false
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
    }
}

struct AppIconGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Choose a style")
                    .font(.title2)
                    .bold()

                // Purple version
                VStack(spacing: 12) {
                    AppIconView(style: .purple)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Text("Purple")
                        .font(.headline)

                    Button {
                        generateAndShare(style: .purple)
                    } label: {
                        Label("Share Purple", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 10)

                // Dark Gray version
                VStack(spacing: 12) {
                    AppIconView(style: .darkGray)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Text("Dark Gray")
                        .font(.headline)

                    Button {
                        generateAndShare(style: .darkGray)
                    } label: {
                        Label("Share Dark Gray", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 10)

                Text("Dark Mode Variants")
                    .font(.title3)
                    .bold()
                    .padding(.top, 10)

                Text("Optimized for Liquid Glass dark appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Purple Dark Mode
                VStack(spacing: 12) {
                    AppIconView(style: .purpleDark)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Text("Purple Dark")
                        .font(.headline)

                    Button {
                        generateAndShare(style: .purpleDark)
                    } label: {
                        Label("Share Purple Dark", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                Divider()
                    .padding(.vertical, 10)

                // Dark Gray Dark Mode
                VStack(spacing: 12) {
                    AppIconView(style: .darkGrayDark)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 40))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Text("Dark Gray Dark")
                        .font(.headline)

                    Button {
                        generateAndShare(style: .darkGrayDark)
                    } label: {
                        Label("Share Dark Gray Dark", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                Text("1024 × 1024 px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
            .padding(.vertical, 30)
        }
        .navigationTitle("App Icon Generator")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
                    .ignoresSafeArea()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func generateAndShare(style: AppIconStyle) {
        guard let image = AppIconGenerator.generateIcon(style: style),
              let data = image.pngData() else {
            errorMessage = "Failed to generate icon image"
            showError = true
            return
        }

        // Save to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "AppIcon-\(style).png"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            shareURL = fileURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to save icon: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        AppIconGeneratorView()
    }
}
