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
    private let db = DatabaseManager.shared

    func loadAccounts() async {
        AppLogger.data.info("📄 Loading accounts for profiles...")

        if let cached = try? db.fetchAccounts(), !cached.isEmpty {
            accounts = cached
            if selectedAccountId.isEmpty, let first = cached.first {
                selectedAccountId = first.id
            }
        }

        do {
            let fresh = try await accountService.list()
            accounts = fresh
            try? db.saveAccounts(fresh)
            if selectedAccountId.isEmpty, let first = fresh.first {
                selectedAccountId = first.id
            }
            await loadAll()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
            if !selectedAccountId.isEmpty { await loadAll() }
        }
    }

    func loadAll() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📄 Loading all profile data for account=\(self.selectedAccountId)")
        isLoading = true
        errorMessage = nil

        if let cachedProfiles = try? db.fetchProfiles(accountId: selectedAccountId), !cachedProfiles.isEmpty {
            profiles = Self.deduplicateProfiles(cachedProfiles)
        }
        if let cachedBundles = try? db.fetchBundleIds(accountId: selectedAccountId), !cachedBundles.isEmpty {
            bundleIds = cachedBundles
        }

        do {
            async let p = service.list(accountId: selectedAccountId)
            async let t = service.types()
            async let b = service.bundleIds(accountId: selectedAccountId)
            let freshProfiles = try await p
            profileTypes = try await t
            let freshBundles = try await b
            profiles = Self.deduplicateProfiles(freshProfiles)
            bundleIds = freshBundles
            try? db.saveProfiles(freshProfiles, accountId: selectedAccountId)
            try? db.saveBundleIds(freshBundles, accountId: selectedAccountId)
            AppLogger.data.info("📄 Loaded \(self.profiles.count) profiles, \(self.bundleIds.count) bundleIDs")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if profiles.isEmpty && bundleIds.isEmpty { errorMessage = error.localizedDescription }
                AppLogger.data.error("📄 Load all failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadProfileDeps() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📄 Loading profile deps (certs + devices)...")

        if let cachedCerts = try? db.fetchCertificates(accountId: selectedAccountId), !cachedCerts.isEmpty {
            certificates = Self.deduplicateCerts(cachedCerts)
        }
        if let cachedDevices = try? db.fetchDevices(accountId: selectedAccountId), !cachedDevices.isEmpty {
            devices = cachedDevices
        }

        do {
            async let c = certService.list(accountId: selectedAccountId)
            async let d = deviceService.list(accountId: selectedAccountId)
            let freshCerts = try await c
            let freshDevices = try await d
            certificates = Self.deduplicateCerts(freshCerts)
            devices = freshDevices
            try? db.saveCertificates(freshCerts, accountId: selectedAccountId)
            try? db.saveDevices(freshDevices, accountId: selectedAccountId)
            AppLogger.data.info("📄 Deps loaded | certs=\(self.certificates.count) devices=\(self.devices.count)")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if certificates.isEmpty && devices.isEmpty { errorMessage = error.localizedDescription }
                AppLogger.data.error("📄 Load deps failed | \(error.localizedDescription)")
            }
        }
    }

    func loadBundleIds() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("📄 Loading bundle IDs...")

        if let cached = try? db.fetchBundleIds(accountId: selectedAccountId), !cached.isEmpty {
            bundleIds = cached
        }

        do {
            let fresh = try await service.bundleIds(accountId: selectedAccountId)
            bundleIds = fresh
            try? db.saveBundleIds(fresh, accountId: selectedAccountId)
            AppLogger.data.info("📄 Loaded \(self.bundleIds.count) bundle IDs")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if bundleIds.isEmpty { errorMessage = error.localizedDescription }
            }
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
        try? db.deleteProfile(id: id)
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
        try? db.deleteBundleId(id: id)
    }

    private static func deduplicateProfiles(_ items: [Profile]) -> [Profile] {
        var seen: [String: Int] = [:]
        var result: [Profile] = []
        for item in items {
            let key = item.apple_id ?? item.id
            if let idx = seen[key] {
                let existing = result[idx]
                if existing.profile_path == nil && item.profile_path != nil {
                    result[idx] = item
                }
            } else {
                seen[key] = result.count
                result.append(item)
            }
        }
        return result
    }

    private static func deduplicateCerts(_ certs: [Certificate]) -> [Certificate] {
        var seen: [String: Int] = [:]
        var result: [Certificate] = []
        for cert in certs {
            let key = cert.apple_id ?? cert.id
            if let idx = seen[key] {
                let existing = result[idx]
                if existing.p12_path == nil && cert.p12_path != nil {
                    result[idx] = cert
                }
            } else {
                seen[key] = result.count
                result.append(cert)
            }
        }
        return result
    }
}
