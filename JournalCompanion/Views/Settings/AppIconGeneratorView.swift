import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct AppIconGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var iconImage: UIImage?
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
            if let image = iconImage {
                ShareSheet(items: [image])
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func generateAndShare(style: AppIconStyle) {
        guard let image = AppIconGenerator.generateIcon(style: style) else {
            errorMessage = "Failed to generate icon image"
            showError = true
            return
        }

        iconImage = image
        showShareSheet = true
    }
}

#Preview {
    NavigationStack {
        AppIconGeneratorView()
    }
}
