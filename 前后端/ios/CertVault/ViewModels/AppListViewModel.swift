import Foundation

@MainActor
final class AppListViewModel: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var builds: [AppBuild] = []
    @Published var versions: [AppVersion] = []
    @Published var accounts: [Account] = []
    @Published var selectedAccountId = ""
    @Published var isLoading = false
    @Published var isLoadingBuilds = false
    @Published var isLoadingVersions = false
    @Published var errorMessage: String?

    private let service = AppStoreConnectService()
    private let accountService = AccountService()
    private var initialLoadDone = false

    func loadAccounts() async {
        do {
            accounts = try await accountService.list()
            if selectedAccountId.isEmpty, let first = accounts.first {
                selectedAccountId = first.id
                initialLoadDone = true
                await loadApps()
            }
        } catch {
            if !Task.isCancelled { errorMessage = "加载账号失败: \(error.localizedDescription)" }
        }
    }

    func onAccountChanged() {
        guard initialLoadDone else { return }
        Task { await loadApps() }
    }

    func loadApps() async {
        guard !selectedAccountId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            apps = try await service.listApps(accountId: selectedAccountId)
            if apps.isEmpty {
                errorMessage = "该账号下没有找到应用，请确认账号 API 密钥权限包含 App Store Connect"
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = "加载应用失败: \(error.localizedDescription)"
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadBuilds(appId: String) async {
        isLoadingBuilds = true
        builds = []
        errorMessage = nil
        do {
            builds = try await service.listBuilds(appId: appId, accountId: selectedAccountId)
        } catch {
            if !Task.isCancelled {
                errorMessage = "加载构建版本失败: \(error.localizedDescription)"
            }
        }
        if !Task.isCancelled { isLoadingBuilds = false }
    }

    func loadVersions(appId: String) async {
        isLoadingVersions = true
        versions = []
        errorMessage = nil
        do {
            versions = try await service.listVersions(appId: appId, accountId: selectedAccountId)
        } catch {
            if !Task.isCancelled {
                errorMessage = "加载版本失败: \(error.localizedDescription)"
            }
        }
        if !Task.isCancelled { isLoadingVersions = false }
    }
}
