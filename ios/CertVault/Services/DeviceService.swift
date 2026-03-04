import Foundation

struct DeviceService {
    private let api = APIClient.shared

    func list(accountId: String) async throws -> [Device] {
        let resp: APIResponse<[Device]> = try await api.request(
            "/devices", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func detail(deviceId: String) async throws -> Device {
        let resp: APIResponse<Device> = try await api.request("/devices/\(deviceId)/detail")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func register(accountId: String, name: String, udid: String, platform: String = "IOS") async throws -> Device {
        struct Body: Encodable {
            let account_id: String
            let name: String
            let udid: String
            let platform: String
        }
        let resp: APIResponse<Device> = try await api.request(
            "/devices", method: "POST",
            body: Body(account_id: accountId, name: name, udid: udid, platform: platform)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "注册失败") }
        return data
    }

    func batchRegister(accountId: String, devices: [[String: String]]) async throws {
        struct Body: Encodable {
            let account_id: String
            let devices: [[String: String]]
        }
        _ = try await api.requestRaw(
            "/devices/batch", method: "POST",
            body: Body(account_id: accountId, devices: devices)
        )
    }

    func autoBind(request: AutoBindRequest) async throws -> AutoBindResult {
        let resp: APIResponse<AutoBindResult> = try await api.request(
            "/devices/auto-bindall", method: "POST", body: request
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "绑定失败") }
        return data
    }

    func setStatus(deviceId: String, status: String) async throws -> Device {
        struct Body: Encodable { let status: String }
        let resp: APIResponse<Device> = try await api.request(
            "/devices/\(deviceId)/status", method: "PATCH",
            body: Body(status: status)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "操作失败") }
        return data
    }

    func setStatus(deviceId: String, enabled: Bool) async throws -> Device {
        struct Body: Encodable { let status: String }
        let resp: APIResponse<Device> = try await api.request(
            "/devices/\(deviceId)/status", method: "PATCH",
            body: Body(status: enabled ? "ENABLED" : "DISABLED")
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "操作失败") }
        return data
    }

    func delete(deviceId: String, keepApple: Bool = false) async throws {
        var path = "/devices/\(deviceId)"
        if keepApple { path += "?keep_apple=true" }
        let resp = try await api.requestRaw(path, method: "DELETE")
        if !resp.success { throw APIError.serverError(resp.message ?? "删除失败") }
    }

    func resources(deviceId: String) async throws -> DeviceResources {
        let resp: APIResponse<DeviceResources> = try await api.request("/devices/\(deviceId)/resources")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }
}
