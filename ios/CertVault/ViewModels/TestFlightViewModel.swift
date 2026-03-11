import Foundation

@MainActor
final class TestFlightViewModel: ObservableObject {
    @Published var groups: [BetaGroup] = []
    @Published var testers: [BetaTester] = []
    @Published var builds: [AppBuild] = []
    @Published var groupTesters: [BetaTester] = []
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

    func loadGroups() async {
        guard !selectedAccountId.isEmpty else { return }
        isLoading = true
        do {
            groups = try await service.listGroups(
                accountId: selectedAccountId,
                appId: selectedAppId.isEmpty ? nil : selectedAppId
            )
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadTesters() async {
        guard !selectedAccountId.isEmpty else { return }
        isLoading = true
        do {
            testers = try await service.listTesters(accountId: selectedAccountId)
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadBuilds() async {
        guard !selectedAccountId.isEmpty, !selectedAppId.isEmpty else { return }
        do {
            builds = try await service.listBuilds(appId: selectedAppId, accountId: selectedAccountId)
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func createGroup(name: String, isInternal: Bool) async throws {
        guard !selectedAppId.isEmpty else { throw APIError.serverError("请先选择应用") }
        try await service.createGroup(accountId: selectedAccountId, appId: selectedAppId, name: name, isInternal: isInternal)
        await loadGroups()
    }

    func deleteGroup(id: String) async throws {
        try await service.deleteGroup(id: id, accountId: selectedAccountId)
        groups.removeAll { $0.id == id }
    }

    func createTester(email: String, firstName: String, lastName: String, groupIds: [String] = []) async throws {
        try await service.createTester(accountId: selectedAccountId, email: email, firstName: firstName, lastName: lastName, groupIds: groupIds)
        await loadTesters()
    }

    func deleteTester(id: String) async throws {
        try await service.deleteTester(id: id, accountId: selectedAccountId)
        testers.removeAll { $0.id == id }
    }

    func loadGroupTesters(groupId: String) async {
        do {
            groupTesters = try await service.groupTesters(groupId: groupId, accountId: selectedAccountId)
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func addBuildsToGroup(groupId: String, buildIds: [String], whatsNew: String? = nil, locale: String = "en-US") async throws {
        try await service.addBuildsToGroup(groupId: groupId, accountId: selectedAccountId, buildIds: buildIds, whatsNew: whatsNew, locale: locale)
        await loadBuilds()
        await loadGroups()
    }

    func addTestersToGroup(groupId: String, testerIds: [String]) async throws {
        try await service.addTestersToGroup(groupId: groupId, accountId: selectedAccountId, testerIds: testerIds)
        await loadGroupTesters(groupId: groupId)
    }

    func removeTestersFromGroup(groupId: String, testerIds: [String]) async throws {
        try await service.removeTestersFromGroup(groupId: groupId, accountId: selectedAccountId, testerIds: testerIds)
        await loadGroupTesters(groupId: groupId)
    }

    func submitForBetaReview(buildId: String) async throws {
        try await service.submitForBetaReview(buildId: buildId, accountId: selectedAccountId)
    }

    func getBetaReviewStatus(buildId: String) async -> BetaReviewStatus? {
        try? await service.getBetaReviewStatus(buildId: buildId, accountId: selectedAccountId)
    }
}
