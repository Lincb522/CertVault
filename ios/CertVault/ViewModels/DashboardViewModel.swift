import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var stats: DashboardStats?
    @Published var recentCerts: [RecentCertificate] = []
    @Published var recentDevices: [RecentDevice] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var needsRefresh = false

    private let api = APIClient.shared
    private let db = DatabaseManager.shared
    private var loginObserver: Any?

    deinit {
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    static let didLoginNotification = Notification.Name("DashboardDidLogin")

    func startObserving() {
        guard loginObserver == nil else { return }
        loginObserver = NotificationCenter.default.addObserver(
            forName: Self.didLoginNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.needsRefresh = true
            }
        }
    }

    func loadCached() {
        if stats != nil { return }
        do {
            if let localStats = try db.computeLocalStats() {
                stats = localStats
                recentCerts = try db.fetchRecentCertificatesLocal()
                recentDevices = try db.fetchRecentDevicesLocal()
                AppLogger.data.info("📊 Dashboard cached | accounts=\(localStats.accounts) devices=\(localStats.devices)")
            }
        } catch {
            AppLogger.data.error("📊 Dashboard cache read failed | \(error.localizedDescription)")
        }
    }

    func load() async {
        AppLogger.data.info("📊 Dashboard loading...")
        let hadData = stats != nil
        if !hadData { isLoading = true }
        errorMessage = nil
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
                if stats == nil { errorMessage = error.localizedDescription }
                AppLogger.data.error("📊 Dashboard failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }
}
