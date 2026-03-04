import Foundation

@MainActor
final class CertificateViewModel: ObservableObject {
    @Published var certificates: [Certificate] = []
    @Published var certTypes: [CertificateType] = []
    @Published var quotas: [String: CertQuota] = [:]
    @Published var relations: [CertRelation] = []
    @Published var selectedCert: Certificate?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAccountId: String = ""
    @Published var accounts: [Account] = []

    private let service = CertificateService()
    private let accountService = AccountService()

    func loadAccounts() async {
        AppLogger.data.info("🔏 Loading accounts for certs...")
        do {
            accounts = try await accountService.list()
            if selectedAccountId.isEmpty, let first = accounts.first {
                selectedAccountId = first.id
                await loadCertificates()
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadCertificates() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("🔏 Loading certificates for account=\(self.selectedAccountId)")
        isLoading = true
        errorMessage = nil
        do {
            async let certs = service.list(accountId: selectedAccountId)
            async let types = service.types()
            certificates = try await certs
            certTypes = try await types
            AppLogger.data.info("🔏 Loaded \(self.certificates.count) certs, \(self.certTypes.count) types")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("🔏 Load certs failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func loadQuota() async {
        guard !selectedAccountId.isEmpty else { return }
        AppLogger.data.info("🔏 Loading quota...")
        do {
            quotas = try await service.quota(accountId: selectedAccountId)
            AppLogger.data.info("🔏 Loaded \(self.quotas.count) quota entries")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                AppLogger.data.error("🔏 Load quota failed | \(error.localizedDescription)")
            }
        }
    }

    func loadDetail(id: String) async {
        AppLogger.data.info("🔏 Loading cert detail id=\(id)")
        isLoading = true
        do {
            selectedCert = try await service.detail(id: id)
            AppLogger.data.info("🔏 Cert detail: \(self.selectedCert?.name ?? "?") type=\(self.selectedCert?.type ?? "?")")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                AppLogger.data.error("🔏 Cert detail failed | \(error.localizedDescription)")
            }
        }
        if !Task.isCancelled { isLoading = false }
    }

    func create(type: String, name: String?, password: String, revokeAndRecreate: Bool = false) async throws -> Certificate {
        AppLogger.data.info("🔏 Creating cert type=\(type) name=\(name ?? "auto") revoke=\(revokeAndRecreate)")
        let cert = try await service.create(
            accountId: selectedAccountId, type: type,
            name: name, password: password, revokeAndRecreate: revokeAndRecreate
        )
        AppLogger.data.info("🔏 Cert created: \(cert.name ?? "?")")
        await loadCertificates()
        return cert
    }

    func selfSign(name: String, password: String, commonName: String, email: String?) async throws {
        AppLogger.data.info("🔏 Self-signing cert: \(commonName)")
        _ = try await service.selfSign(name: name, password: password, commonName: commonName, email: email)
        AppLogger.data.info("🔏 Self-sign complete")
        await loadCertificates()
    }

    func generateCA(commonName: String, organization: String?, country: String?) async throws {
        AppLogger.data.info("🔏 Generating CA: \(commonName)")
        try await service.generateCA(commonName: commonName, organization: organization, country: country)
        AppLogger.data.info("🔏 CA generated")
    }

    func delete(id: String) async throws {
        AppLogger.data.info("🔏 Deleting cert id=\(id)")
        try await service.delete(id: id)
        certificates.removeAll { $0.id == id }
        AppLogger.data.info("🔏 Cert deleted")
    }

    func loadRelations() async {
        guard !selectedAccountId.isEmpty else { return }
        do {
            relations = try await service.relations(accountId: selectedAccountId)
            AppLogger.data.info("🔏 Loaded \(self.relations.count) relations")
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                AppLogger.data.error("🔏 Load relations failed | \(error.localizedDescription)")
            }
        }
    }
}
