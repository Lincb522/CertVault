import Foundation

struct CapabilityService {
    private let api = APIClient.shared

    func available() async throws -> AvailableCapabilitiesResponse {
        let resp: APIResponse<AvailableCapabilitiesResponse> = try await api.request("/capabilities/available")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func list(bundleId: String, accountId: String) async throws -> [CapabilityItem] {
        let resp: APIResponse<[CapabilityItem]> = try await api.request(
            "/capabilities/\(bundleId)",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func enable(accountId: String, bundleId: String, capabilityType: String) async throws {
        struct Body: Encodable {
            let account_id: String
            let bundle_id: String
            let capability_type: String
        }
        let resp = try await api.requestRaw(
            "/capabilities/enable", method: "POST",
            body: Body(account_id: accountId, bundle_id: bundleId, capability_type: capabilityType)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "开启失败") }
    }

    func disable(accountId: String, capabilityId: String) async throws {
        struct Body: Encodable {
            let account_id: String
            let capability_id: String
        }
        let resp = try await api.requestRaw(
            "/capabilities/disable", method: "POST",
            body: Body(account_id: accountId, capability_id: capabilityId)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "关闭失败") }
    }

    func batchEnable(accountId: String, bundleId: String, types: [String]) async throws {
        struct Body: Encodable {
            let account_id: String
            let bundle_id: String
            let capability_types: [String]
        }
        let resp = try await api.requestRaw(
            "/capabilities/batch-enable", method: "POST",
            body: Body(account_id: accountId, bundle_id: bundleId, capability_types: types)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "批量开启失败") }
    }

    func batchDisable(accountId: String, capabilityIds: [String]) async throws {
        struct Body: Encodable {
            let account_id: String
            let capability_ids: [String]
        }
        let resp = try await api.requestRaw(
            "/capabilities/batch-disable", method: "POST",
            body: Body(account_id: accountId, capability_ids: capabilityIds)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "批量关闭失败") }
    }
}
