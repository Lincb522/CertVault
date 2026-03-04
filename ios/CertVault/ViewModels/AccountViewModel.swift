import Foundation

@MainActor
final class AccountViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var selectedAccount: Account?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var testResult: String?
    @Published var isTesting = false

    private let service = AccountService()
    private let db = DatabaseManager.shared

    func loadAccounts() async {
        AppLogger.data.info("👤 Loading accounts...")
        isLoading = true
        errorMessage = nil

        if let cached = try? db.fetchAccounts(), !cached.isEmpty {
            accounts = cached
        }

        do {
            let fresh = try await service.list()
            accounts = fresh
            try? db.saveAccounts(fresh)
            AppLogger.data.info("👤 Loaded \(self.accounts.count) accounts")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                if accounts.isEmpty { errorMessage = error.localizedDescription }
                AppLogger.data.error("👤 Load accounts failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadDetail(id: String) async {
        AppLogger.data.info("👤 Loading account detail id=\(id)")
        isLoading = true
        errorMessage = nil
        do {
            selectedAccount = try await service.get(id: id)
            AppLogger.data.info("👤 Account detail loaded: \(self.selectedAccount?.name ?? "?")")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("👤 Account detail failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func create(name: String, issuerID: String, keyID: String, privateKey: String) async throws {
        AppLogger.data.info("👤 Creating account: \(name)")
        let _ = try await service.create(name: name, issuerID: issuerID, keyID: keyID, privateKey: privateKey)
        AppLogger.data.info("👤 Account created: \(name)")
        await loadAccounts()
    }

    func update(id: String, name: String, issuerID: String, keyID: String, privateKey: String?) async throws {
        AppLogger.data.info("👤 Updating account id=\(id)")
        try await service.update(id: id, name: name, issuerID: issuerID, keyID: keyID, privateKey: privateKey)
        AppLogger.data.info("👤 Account updated")
        await loadAccounts()
    }

    func delete(id: String) async throws {
        AppLogger.data.info("👤 Deleting account id=\(id)")
        try await service.delete(id: id)
        accounts.removeAll { $0.id == id }
        try? db.deleteAccount(id: id)
        AppLogger.data.info("👤 Account deleted")
    }

    func testConnection(id: String) async {
        AppLogger.data.info("👤 Testing connection id=\(id)")
        isTesting = true
        testResult = nil
        do {
            let result = try await service.test(id: id)
            testResult = "连接成功！发现 \(result.certificates_found ?? 0) 个证书"
            AppLogger.data.info("👤 Connection test OK | certs=\(result.certificates_found ?? 0)")
        } catch is CancellationError {
            isTesting = false
            return
        } catch {
            if !Task.isCancelled {
                testResult = "连接失败: \(error.localizedDescription)"
                AppLogger.data.error("👤 Connection test failed | \(error.localizedDescription)")
            }
        }
        isTesting = false
    }

    func uploadP8(accountId: String, fileData: Data, fileName: String) async throws {
        AppLogger.data.info("👤 Uploading P8 file: \(fileName)")
        let _ = try await service.uploadP8(accountId: accountId, fileData: fileData, fileName: fileName)
        AppLogger.data.info("👤 P8 uploaded: \(fileName)")
        await loadAccounts()
    }

    func importP8(name: String, issuerID: String, keyID: String, privateKey: String) async throws {
        AppLogger.data.info("👤 Importing P8: \(name)")
        let _ = try await service.importP8(name: name, issuerID: issuerID, keyID: keyID, privateKey: privateKey)
        AppLogger.data.info("👤 P8 imported: \(name)")
        await loadAccounts()
    }
}
