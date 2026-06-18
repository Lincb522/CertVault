import Foundation

struct CertificateService {
    private let api = APIClient.shared

    func list(accountId: String) async throws -> [Certificate] {
        let resp: APIResponse<[Certificate]> = try await api.request(
            "/certificates", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func types() async throws -> [CertificateType] {
        let resp: APIResponse<[CertificateType]> = try await api.request("/certificates/types")
        return resp.data ?? []
    }

    func quota(accountId: String) async throws -> [String: CertQuota] {
        let data = try await api.requestData(
            "/certificates/quota", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            throw APIError.noData
        }

        var result: [String: CertQuota] = [:]
        for (key, value) in dataObj {
            if key == "total_certs" { continue }
            if let dict = value as? [String: Any],
               let used = dict["used"] as? Int,
               let limit = dict["limit"] as? Int,
               let available = dict["available"] as? Int {
                result[key] = CertQuota(
                    label: dict["label"] as? String,
                    used: used, limit: limit, available: available
                )
            }
        }
        return result
    }

    func create(accountId: String, type: String, name: String?, password: String, revokeAndRecreate: Bool = false) async throws -> Certificate {
        struct Body: Encodable {
            let account_id: String
            let type: String
            let name: String?
            let password: String
            let revoke_and_recreate: Bool
        }
        let resp: APIResponse<Certificate> = try await api.request(
            "/certificates/create", method: "POST",
            body: Body(account_id: accountId, type: type, name: name, password: password, revoke_and_recreate: revokeAndRecreate)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "创建失败") }
        return data
    }

    func selfSign(name: String, password: String, commonName: String, email: String?) async throws -> Certificate {
        struct Subject: Encodable {
            let commonName: String
            let email: String?
        }
        struct Body: Encodable {
            let name: String
            let password: String
            let subject: Subject
        }
        let resp: APIResponse<Certificate> = try await api.request(
            "/certificates/self-sign", method: "POST",
            body: Body(name: name, password: password, subject: Subject(commonName: commonName, email: email))
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "自签失败") }
        return data
    }

    func generateCA(commonName: String, organization: String?, country: String?, years: Int = 10) async throws {
        struct Body: Encodable {
            let commonName: String
            let organization: String?
            let country: String?
            let years: Int
        }
        let resp = try await api.requestRaw(
            "/certificates/generate-ca", method: "POST",
            body: Body(commonName: commonName, organization: organization, country: country, years: years)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "生成 CA 失败") }
    }

    func detail(id: String) async throws -> Certificate {
        let resp: APIResponse<Certificate> = try await api.request("/certificates/\(id)/detail")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func delete(id: String) async throws {
        _ = try await api.requestRaw("/certificates/\(id)", method: "DELETE")
    }

    func relations(accountId: String) async throws -> [CertRelation] {
        let resp: APIResponse<[CertRelation]> = try await api.request(
            "/certificates/relations", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func pushGuide() async throws -> PushGuide {
        let resp: APIResponse<PushGuide> = try await api.request("/certificates/push-guide")
        return resp.data ?? PushGuide(methods: [], common_services: [])
    }
}
