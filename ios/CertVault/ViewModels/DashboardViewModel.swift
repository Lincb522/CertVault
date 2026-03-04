import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var stats: DashboardStats?
    @Published var recentCerts: [RecentCertificate] = []
    @Published var recentDevices: [RecentDevice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func load() async {
        AppLogger.data.info("📊 Dashboard loading...")
        isLoading = true
        errorMessage = nil
        defer { if !Task.isCancelled { isLoading = false } }
        do {
            let resp: APIResponse<DashboardData> = try await api.request("/dashboard")
            if let data = resp.data {
                stats = data.stats
                recentCerts = data.recent_certificates ?? []
                recentDevices = data.recent_devices ?? []
                AppLogger.data.info("📊 Dashboard loaded | accounts=\(data.stats.accounts) devices=\(data.stats.devices) certs=\(data.stats.certificates) profiles=\(data.stats.profiles)")
            }
        } catch is CancellationError {
            AppLogger.data.info("📊 Dashboard cancelled")
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("📊 Dashboard failed | \(error.localizedDescription)")
            }
        }
    }
}
