import Foundation

struct PushService {
    private let api = APIClient.shared

    // Push Keys
    func listKeys() async throws -> [PushKey] {
        let resp: APIResponse<[PushKey]> = try await api.request("/push-keys")
        return resp.data ?? []
    }

    func createKey(name: String, keyId: String, teamId: String, bundleIds: String, p8Content: String) async throws {
        struct Body: Encodable {
            let name: String
            let key_id: String
            let team_id: String
            let bundle_ids: String
            let private_key: String
        }
        let resp = try await api.requestRaw(
            "/push-keys", method: "POST",
            body: Body(name: name, key_id: keyId, team_id: teamId, bundle_ids: bundleIds, private_key: p8Content)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "创建失败") }
    }

    func updateKey(id: String, name: String, keyId: String, teamId: String, bundleIds: String) async throws {
        struct Body: Encodable {
            let name: String
            let key_id: String
            let team_id: String
            let bundle_ids: String
        }
        let resp = try await api.requestRaw(
            "/push-keys/\(id)", method: "PUT",
            body: Body(name: name, key_id: keyId, team_id: teamId, bundle_ids: bundleIds)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新失败") }
    }

    func deleteKey(id: String) async throws {
        _ = try await api.requestRaw("/push-keys/\(id)", method: "DELETE")
    }

    // Send Push
    func send(request: PushRequest) async throws -> PushResult {
        let resp: APIResponse<PushResult> = try await api.request("/push/send", method: "POST", body: request)
        guard let data = resp.data else {
            if resp.success { return PushResult(apns_id: nil, status: "success") }
            throw APIError.serverError(resp.message ?? "发送失败")
        }
        return data
    }

    func errorCodes() async throws -> [APNsErrorCode] {
        let resp: APIResponse<[APNsErrorCode]> = try await api.request("/push/error-codes")
        return resp.data ?? []
    }

    // Device Token Registration
    func registerDevice(token: String, platform: String = "ios") async throws {
        struct Body: Encodable {
            let device_token: String
            let platform: String
        }
        let resp = try await api.requestRaw(
            "/push/register-device", method: "POST",
            body: Body(device_token: token, platform: platform)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "注册设备 Token 失败") }
    }

    func unregisterDevice(token: String) async throws {
        struct Body: Encodable {
            let device_token: String
        }
        let resp = try await api.requestRaw(
            "/push/unregister-device", method: "DELETE",
            body: Body(device_token: token)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "注销设备 Token 失败") }
    }
}

struct APNsErrorCode: Decodable, Identifiable {
    let code: Int?
    let reason: String?
    let desc: String?
    
    var id: String { "\(code ?? 0)-\(reason ?? "")" }
}

struct PushRequest: Encodable {
    var push_key_id: String?
    var account_id: String?
    var team_id: String?
    var key_id: String?
    var private_key: String?
    var device_token: String
    var bundle_id: String
    var title: String
    var body: String
    var badge: Int?
    var sound: String?
    var sandbox: Bool
    var custom_data: [String: String]?
}

struct PushResult: Decodable {
    let apns_id: String?
    let status: String?
}
