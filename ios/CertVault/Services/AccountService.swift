import Foundation

struct AccountService {
    private let api = APIClient.shared

    func list() async throws -> [Account] {
        let resp: APIResponse<[Account]> = try await api.request("/accounts")
        return resp.data ?? []
    }

    func get(id: String) async throws -> Account {
        let resp: APIResponse<Account> = try await api.request("/accounts/\(id)")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func create(name: String, issuerID: String, keyID: String, privateKey: String) async throws -> Account {
        struct Body: Encodable {
            let name: String
            let issuer_id: String
            let key_id: String
            let private_key: String
        }
        let resp: APIResponse<Account> = try await api.request(
            "/accounts", method: "POST",
            body: Body(name: name, issuer_id: issuerID, key_id: keyID, private_key: privateKey)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "创建失败") }
        return data
    }

    func update(id: String, name: String, issuerID: String, keyID: String, privateKey: String?) async throws {
        struct Body: Encodable {
            let name: String
            let issuer_id: String
            let key_id: String
            let private_key: String?
        }
        _ = try await api.requestRaw(
            "/accounts/\(id)", method: "PUT",
            body: Body(name: name, issuer_id: issuerID, key_id: keyID, private_key: privateKey)
        )
    }

    func delete(id: String) async throws {
        _ = try await api.requestRaw("/accounts/\(id)", method: "DELETE")
    }

    func test(id: String) async throws -> TestConnectionResult {
        let resp: APIResponse<TestConnectionResult> = try await api.request("/accounts/\(id)/test", method: "POST")
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "测试失败") }
        return data
    }

    func validateP8(content: String) async throws -> Bool {
        struct Body: Encodable { let content: String }
        let resp = try await api.requestRaw("/accounts/validate-p8", method: "POST", body: Body(content: content))
        return resp.success
    }

    func uploadP8(accountId: String, fileData: Data, fileName: String) async throws -> Account {
        let resp: APIResponse<Account> = try await api.upload(
            "/accounts/upload-p8",
            fileData: fileData,
            fieldName: "file",
            fileName: fileName,
            mimeType: "application/x-pem-file",
            extraFields: ["account_id": accountId]
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "上传失败") }
        return data
    }

    func importP8(name: String, issuerID: String, keyID: String, privateKey: String) async throws -> Account {
        struct Body: Encodable {
            let name: String
            let issuer_id: String
            let key_id: String
            let private_key: String
        }
        let resp: APIResponse<Account> = try await api.request(
            "/accounts/import-p8", method: "POST",
            body: Body(name: name, issuer_id: issuerID, key_id: keyID, private_key: privateKey)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "导入失败") }
        return data
    }
}
