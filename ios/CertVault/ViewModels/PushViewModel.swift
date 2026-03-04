import Foundation

@MainActor
final class PushViewModel: ObservableObject {
    @Published var pushKeys: [PushKey] = []
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sendResult: String?
    @Published var isSending = false
    @Published var pushGuide: PushGuide?
    @Published var errorCodes: [APNsErrorCode] = []

    private let service = PushService()
    private let accountService = AccountService()
    private let certService = CertificateService()
    private let db = DatabaseManager.shared

    func loadKeys() async {
        AppLogger.data.info("🔔 Loading push keys...")
        isLoading = true
        errorMessage = nil

        if let cached = try? db.fetchPushKeys(), !cached.isEmpty {
            pushKeys = cached
        }

        do {
            let fresh = try await service.listKeys()
            pushKeys = fresh
            try? db.savePushKeys(fresh)
            AppLogger.data.info("🔔 Loaded \(self.pushKeys.count) push keys")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if pushKeys.isEmpty { errorMessage = error.localizedDescription }
                AppLogger.data.error("🔔 Load keys failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadAccounts() async {
        if let cached = try? db.fetchAccounts(), !cached.isEmpty {
            accounts = cached
        }

        do {
            let fresh = try await accountService.list()
            accounts = fresh
            try? db.saveAccounts(fresh)
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if accounts.isEmpty { errorMessage = error.localizedDescription }
                AppLogger.data.error("🔔 Load accounts failed | \(error.localizedDescription)")
            }
        }
    }

    func createKey(name: String, keyId: String, teamId: String, bundleIds: String, p8Content: String) async throws {
        AppLogger.data.info("🔔 Creating push key: \(name)")
        try await service.createKey(name: name, keyId: keyId, teamId: teamId, bundleIds: bundleIds, p8Content: p8Content)
        AppLogger.data.info("🔔 Push key created: \(name)")
        await loadKeys()
    }

    func updateKey(id: String, name: String, keyId: String, teamId: String, bundleIds: String) async throws {
        AppLogger.data.info("🔔 Updating push key id=\(id)")
        try await service.updateKey(id: id, name: name, keyId: keyId, teamId: teamId, bundleIds: bundleIds)
        AppLogger.data.info("🔔 Push key updated")
        await loadKeys()
    }

    func deleteKey(id: String) async throws {
        AppLogger.data.info("🔔 Deleting push key id=\(id)")
        try await service.deleteKey(id: id)
        pushKeys.removeAll { $0.id == id }
        try? db.deletePushKey(id: id)
    }

    func send(request: PushRequest) async {
        AppLogger.data.info("🔔 Sending push | token=\(request.device_token.prefix(20))... bundle=\(request.bundle_id)")
        isSending = true
        sendResult = nil
        do {
            let result = try await service.send(request: request)
            sendResult = "发送成功！APNs ID: \(result.apns_id ?? "N/A")"
            AppLogger.data.info("🔔 Push sent OK | apns_id=\(result.apns_id ?? "N/A")")
        } catch {
            sendResult = "发送失败: \(error.localizedDescription)"
            AppLogger.data.error("🔔 Push failed | \(error.localizedDescription)")
        }
        isSending = false
    }

    @Published var guideLoaded = false

    func loadPushGuide() async {
        do {
            pushGuide = try await certService.pushGuide()
            AppLogger.data.info("🔔 Push guide loaded")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                AppLogger.data.error("🔔 Load push guide failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { guideLoaded = true }
    }

    func loadErrorCodes() async {
        do {
            errorCodes = try await service.errorCodes()
            AppLogger.data.info("🔔 Loaded \(self.errorCodes.count) error codes")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                AppLogger.data.error("🔔 Load error codes failed | \(error.localizedDescription)")
            }
        }
    }
}
