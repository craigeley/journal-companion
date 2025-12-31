import SwiftUI
import UIKit

enum AppIconStyle {
    case purple
    case darkGray
    case purpleDark      // Dark mode variant
    case darkGrayDark    // Dark mode variant
}

struct AppIconView: View {
    let style: AppIconStyle

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            // Journal icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 500))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var backgroundGradient: some View {
        Group {
            switch style {
            case .purple:
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.35, blue: 0.85), // Lighter purple
                        Color(red: 0.45, green: 0.25, blue: 0.75)  // Darker purple
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .darkGray:
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.25, blue: 0.28), // Lighter gray
                        Color(red: 0.15, green: 0.15, blue: 0.18)  // Darker gray
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .purpleDark:
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.20, blue: 0.55), // Deeper, muted purple
                        Color(red: 0.25, green: 0.12, blue: 0.45)  // Even darker purple
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .darkGrayDark:
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.18, blue: 0.20), // Darker gray (not pure black)
                        Color(red: 0.10, green: 0.10, blue: 0.12)  // Very dark but still visible
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

@MainActor
class AppIconGenerator {
    static func generateIcon(style: AppIconStyle = .purple, size: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage? {
        let view = AppIconView(style: style)
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        // Use scale 1.0 to ensure exactly 1024x1024 pixels, not scaled for retina
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    static func saveIcon(to url: URL, size: CGSize = CGSize(width: 1024, height: 1024)) throws {
        guard let image = generateIcon(size: size),
              let data = image.pngData() else {
            throw NSError(domain: "AppIconGenerator", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to generate icon image"])
        }

        try data.write(to: url)
    }

    static func saveIconToDocuments(filename: String = "AppIcon.png") throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        try saveIcon(to: fileURL)
        print("Icon saved to: \(fileURL.path)")
        return fileURL
    }
}

// Preview
struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconView(style: .purple)
            .frame(width: 1024, height: 1024)
            .previewLayout(.sizeThatFits)
    }
}
