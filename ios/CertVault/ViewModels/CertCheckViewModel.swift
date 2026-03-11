import Foundation

@MainActor
final class CertCheckViewModel: ObservableObject {
    @Published var result: CertCheckResponse?
    @Published var accounts: [Account] = []
    @Published var selectedAccountId = ""
    @Published var password = ""
    @Published var isValidating = false
    @Published var errorMessage: String?

    private let service = CertCheckService()
    private let accountService = AccountService()

    func loadAccounts() async {
        do {
            accounts = try await accountService.list()
        } catch {
            if !Task.isCancelled {
                AppLogger.data.error("📋 Load accounts for cert check failed | \(error.localizedDescription)")
            }
        }
    }

    func validate(fileData: Data, fileName: String) async {
        isValidating = true
        errorMessage = nil
        result = nil
        do {
            result = try await service.validate(
                fileData: fileData,
                fileName: fileName,
                password: password.isEmpty ? nil : password,
                accountId: selectedAccountId.isEmpty ? nil : selectedAccountId
            )
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if !Task.isCancelled { isValidating = false }
    }

    func reset() {
        result = nil
        errorMessage = nil
        password = ""
    }
}
