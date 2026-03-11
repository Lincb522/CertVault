import Foundation

@MainActor
final class AppStoreViewModel: ObservableObject {
    @Published var versions: [AppStoreVersion] = []
    @Published var apps: [AppItem] = []
    @Published var accounts: [Account] = []
    @Published var selectedAccountId = ""
    @Published var selectedAppId = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = AppStoreConnectService()
    private let accountService = AccountService()

    func loadAccounts() async {
        do {
            accounts = try await accountService.list()
            if selectedAccountId.isEmpty, let first = accounts.first {
                selectedAccountId = first.id
                await loadApps()
            }
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func loadApps() async {
        guard !selectedAccountId.isEmpty else { return }
        do {
            apps = try await service.listApps(accountId: selectedAccountId)
            if selectedAppId.isEmpty, let first = apps.first {
                selectedAppId = first.id
            }
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func loadVersions() async {
        guard !selectedAccountId.isEmpty, !selectedAppId.isEmpty else { return }
        isLoading = true
        do {
            versions = try await service.listAppStoreVersions(accountId: selectedAccountId, appId: selectedAppId)
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func createVersion(version: String, platform: String) async throws {
        guard !selectedAppId.isEmpty else { throw APIError.serverError("请先选择应用") }
        try await service.createAppStoreVersion(accountId: selectedAccountId, appId: selectedAppId, version: version, platform: platform)
        await loadVersions()
    }

    func submitForReview(versionId: String) async throws {
        try await service.submitForReview(versionId: versionId, accountId: selectedAccountId)
        await loadVersions()
    }

    func getVersionDetail(id: String) async throws -> AppStoreVersion {
        try await service.getAppStoreVersion(id: id, accountId: selectedAccountId)
    }

    func updateLocalization(id: String, whatsNew: String?, description: String?, keywords: String?) async throws {
        try await service.updateLocalization(id: id, accountId: selectedAccountId, whatsNew: whatsNew, description: description, keywords: keywords)
    }

    // MARK: - Version Build & Release Management

    func getVersionBuild(versionId: String) async throws -> VersionBuildInfo? {
        try await service.getVersionBuild(versionId: versionId, accountId: selectedAccountId)
    }

    func setVersionBuild(versionId: String, buildId: String?) async throws {
        try await service.setVersionBuild(versionId: versionId, accountId: selectedAccountId, buildId: buildId)
    }

    func updateReleaseType(versionId: String, releaseType: String) async throws {
        try await service.updateVersionReleaseType(versionId: versionId, accountId: selectedAccountId, releaseType: releaseType)
        await loadVersions()
    }

    func getPhasedRelease(versionId: String) async throws -> PhasedReleaseInfo? {
        try await service.getPhasedRelease(versionId: versionId, accountId: selectedAccountId)
    }

    func createPhasedRelease(versionId: String) async throws {
        try await service.createPhasedRelease(versionId: versionId, accountId: selectedAccountId)
    }

    func updatePhasedRelease(id: String, state: String) async throws {
        try await service.updatePhasedRelease(id: id, accountId: selectedAccountId, state: state)
    }

    func deletePhasedRelease(id: String) async throws {
        try await service.deletePhasedRelease(id: id, accountId: selectedAccountId)
    }

    func loadBuilds() async throws -> [AppBuild] {
        guard !selectedAppId.isEmpty else { return [] }
        return try await service.listBuilds(appId: selectedAppId, accountId: selectedAccountId)
    }
}
