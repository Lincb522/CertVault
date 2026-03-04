import Foundation

@MainActor
final class CapabilityViewModel: ObservableObject {
    @Published var availableCapabilities: [AvailableCapability] = []
    @Published var enabledCapabilities: [CapabilityItem] = []
    @Published var presets: [String: [String]] = [:]
    @Published var categories: [String: [String]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAccountId: String = ""
    @Published var selectedBundleId: String = ""
    @Published var accounts: [Account] = []
    @Published var bundleIds: [BundleIDItem] = []
    @Published var togglingTypes: Set<String> = []

    private let service = CapabilityService()
    private let accountService = AccountService()
    private let profileService = ProfileService()

    func loadAccounts() async {
        do {
            accounts = try await accountService.list()
            if selectedAccountId.isEmpty, let first = accounts.first {
                selectedAccountId = first.id
                await loadBundleIds()
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func loadBundleIds() async {
        guard !selectedAccountId.isEmpty else { return }
        do {
            bundleIds = try await profileService.bundleIds(accountId: selectedAccountId)
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func loadAvailable() async {
        do {
            let resp = try await service.available()
            availableCapabilities = resp.capabilities ?? []
            presets = resp.presets ?? [:]
            categories = resp.categories ?? [:]
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func loadEnabled() async {
        guard !selectedBundleId.isEmpty && !selectedAccountId.isEmpty else { return }
        isLoading = true
        do {
            enabledCapabilities = try await service.list(bundleId: selectedBundleId, accountId: selectedAccountId)
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func isEnabled(_ type: String) -> Bool {
        enabledCapabilities.contains { $0.type == type && $0.isEnabled }
    }

    func capabilityId(for type: String) -> String? {
        enabledCapabilities.first(where: { $0.type == type && $0.isEnabled })?.id
    }

    func toggle(_ type: String) async {
        togglingTypes.insert(type)
        errorMessage = nil
        do {
            if isEnabled(type) {
                if let capId = capabilityId(for: type) {
                    try await service.disable(accountId: selectedAccountId, capabilityId: capId)
                }
            } else {
                try await service.enable(accountId: selectedAccountId, bundleId: selectedBundleId, capabilityType: type)
            }
            await loadEnabled()
        } catch {
            errorMessage = error.localizedDescription
        }
        togglingTypes.remove(type)
    }

    func applyPreset(_ types: [String]) async {
        isLoading = true
        do {
            try await service.batchEnable(accountId: selectedAccountId, bundleId: selectedBundleId, types: types)
            await loadEnabled()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func disableAll() async {
        let ids = enabledCapabilities.filter(\.isEnabled).compactMap(\.id)
        guard !ids.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await service.batchDisable(accountId: selectedAccountId, capabilityIds: ids)
            await loadEnabled()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
