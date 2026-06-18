import Foundation

@MainActor
final class HealthCheckViewModel: ObservableObject {
    @Published var localResult: HealthCheckResult?
    @Published var remoteResult: HealthCheckResult?
    @Published var isLoadingLocal = false
    @Published var isLoadingRemote = false
    @Published var errorMessage: String?
    @Published var selectedAccountId: String = ""
    @Published var accounts: [Account] = []

    private let service = HealthService()
    private let accountService = AccountService()

    func loadAccounts() async {
        AppLogger.data.info("🩺 Loading accounts for health check...")
        do {
            accounts = try await accountService.list()
            if selectedAccountId.isEmpty, let first = accounts.first {
                selectedAccountId = first.id
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func runLocalCheck() async {
        AppLogger.data.info("🩺 Running local health check...")
        isLoadingLocal = true
        do {
            localResult = try await service.localCheck()
            AppLogger.data.info("🩺 Local check done | issues=\(self.localResult?.issues?.count ?? 0)")
        } catch is CancellationError {
            isLoadingLocal = false
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("🩺 Local check failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoadingLocal = false }
    }

    func runRemoteCheck() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("🩺 Running remote health check for account=\(self.selectedAccountId)")
        isLoadingRemote = true
        do {
            remoteResult = try await service.remoteCheck(accountId: selectedAccountId)
            AppLogger.data.info("🩺 Remote check done | issues=\(self.remoteResult?.issues?.count ?? 0)")
        } catch is CancellationError {
            isLoadingRemote = false
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("🩺 Remote check failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoadingRemote = false }
    }
}
