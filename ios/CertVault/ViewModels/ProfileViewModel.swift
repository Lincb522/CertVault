import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var profileTypes: [ProfileType] = []
    @Published var bundleIds: [BundleIDItem] = []
    @Published var certificates: [Certificate] = []
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAccountId: String = ""
    @Published var accounts: [Account] = []

    private let service = ProfileService()
    private let accountService = AccountService()
    private let certService = CertificateService()
    private let deviceService = DeviceService()

    func loadAccounts() async {
        AppLogger.data.info("📄 Loading accounts for profiles...")
        do {
            accounts = try await accountService.list()
            if selectedAccountId.isEmpty, let first = accounts.first {
                selectedAccountId = first.id
                await loadAll()
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func loadAll() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📄 Loading all profile data for account=\(self.selectedAccountId)")
        isLoading = true
        errorMessage = nil
        do {
            async let p = service.list(accountId: selectedAccountId)
            async let t = service.types()
            async let b = service.bundleIds(accountId: selectedAccountId)
            profiles = try await p
            profileTypes = try await t
            bundleIds = try await b
            AppLogger.data.info("📄 Loaded \(self.profiles.count) profiles, \(self.bundleIds.count) bundleIDs")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("📄 Load all failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadProfileDeps() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📄 Loading profile deps (certs + devices)...")
        do {
            async let c = certService.list(accountId: selectedAccountId)
            async let d = deviceService.list(accountId: selectedAccountId)
            certificates = try await c
            devices = try await d
            AppLogger.data.info("📄 Deps loaded | certs=\(self.certificates.count) devices=\(self.devices.count)")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("📄 Load deps failed | \(error.localizedDescription)")
            }
        }
    }

    func loadBundleIds() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📄 Loading bundle IDs...")
        do {
            bundleIds = try await service.bundleIds(accountId: selectedAccountId)
            AppLogger.data.info("📄 Loaded \(self.bundleIds.count) bundle IDs")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    func createProfile(name: String, type: String, bundleId: String,
                       certIds: [String], deviceIds: [String]) async throws {
        AppLogger.data.info("📄 Creating profile: \(name) type=\(type)")
        _ = try await service.create(
            accountId: selectedAccountId, name: name, type: type,
            bundleId: bundleId, certificateIds: certIds, deviceIds: deviceIds
        )
        AppLogger.data.info("📄 Profile created: \(name)")
        await loadAll()
    }

    func deleteProfile(id: String) async throws {
        AppLogger.data.info("📄 Deleting profile id=\(id)")
        try await service.delete(id: id)
        profiles.removeAll { $0.id == id }
    }

    func createBundleId(identifier: String, name: String) async throws {
        AppLogger.data.info("📄 Creating bundle ID: \(identifier)")
        _ = try await service.createBundleId(accountId: selectedAccountId, identifier: identifier, name: name)
        AppLogger.data.info("📄 Bundle ID created: \(identifier)")
        await loadBundleIds()
    }

    func deleteBundleId(id: String) async throws {
        AppLogger.data.info("📄 Deleting bundle ID id=\(id)")
        try await service.deleteBundleId(id: id)
        bundleIds.removeAll { $0.id == id }
    }
}
