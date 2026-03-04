import SwiftUI

@MainActor
final class FileDownloadService: ObservableObject {
    static let shared = FileDownloadService()

    @Published var isDownloading = false
    @Published var downloadedFileURL: URL?
    @Published var showShareSheet = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func download(endpoint: String, queryItems: [URLQueryItem]? = nil) async {
        AppLogger.api.info("📥 FileDownload start: \(endpoint)")
        isDownloading = true
        errorMessage = nil
        do {
            let (url, filename) = try await api.download(endpoint, queryItems: queryItems)
            downloadedFileURL = url
            showShareSheet = true
            AppLogger.api.info("📥 FileDownload complete: \(filename ?? "unknown") → \(url.lastPathComponent)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.api.error("📥 FileDownload failed: \(endpoint) | \(error.localizedDescription)")
        }
        isDownloading = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
