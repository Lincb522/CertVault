import Foundation
import SwiftUI

struct PushService {
    private let api = APIClient.shared

    // MARK: - Push Keys (migrated to /push/keys)

    func listKeys() async throws -> [PushKey] {
        let resp: APIResponse<[PushKey]> = try await api.request("/push/keys")
        return resp.data ?? []
    }

    func createKey(name: String, keyId: String, teamId: String, bundleIds: String, p8Content: String) async throws {
        struct Body: Encodable {
            let name: String; let key_id: String; let team_id: String
            let bundle_ids: String; let private_key: String
        }
        let resp = try await api.requestRaw(
            "/push/keys", method: "POST",
            body: Body(name: name, key_id: keyId, team_id: teamId, bundle_ids: bundleIds, private_key: p8Content)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "创建失败") }
    }

    func updateKey(id: String, name: String, keyId: String, teamId: String, bundleIds: String) async throws {
        struct Body: Encodable {
            let name: String; let key_id: String; let team_id: String; let bundle_ids: String
        }
        let resp = try await api.requestRaw(
            "/push/keys/\(id)", method: "PUT",
            body: Body(name: name, key_id: keyId, team_id: teamId, bundle_ids: bundleIds)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新失败") }
    }

    func deleteKey(id: String) async throws {
        _ = try await api.requestRaw("/push/keys/\(id)", method: "DELETE")
    }

    // MARK: - Push Settings

    func getSettings() async throws -> PushSettings {
        let resp: APIResponse<PushSettings> = try await api.request("/push/settings")
        return resp.data ?? PushSettings()
    }

    func updateSettings(_ settings: [String: String]) async throws {
        let resp = try await api.requestRaw("/push/settings", method: "PUT", body: settings)
        if !resp.success { throw APIError.serverError(resp.message ?? "更新设置失败") }
    }

    func getStatus() async throws -> PushStatus {
        let resp: APIResponse<PushStatus> = try await api.request("/push/status")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    // MARK: - Send Push

    func send(request: PushRequest) async throws -> PushResult {
        let resp: APIResponse<PushResult> = try await api.request("/push/send", method: "POST", body: request)
        guard let data = resp.data else {
            if resp.success { return PushResult(apns_id: nil, status: .int(200), reason: nil, reason_cn: nil) }
            throw APIError.serverError(resp.message ?? "发送失败")
        }
        return data
    }

    func broadcast(request: BroadcastRequest) async throws -> BroadcastResult {
        let resp: APIResponse<BroadcastResult> = try await api.request("/push/broadcast", method: "POST", body: request)
        guard let data = resp.data else {
            if resp.success { return BroadcastResult(total: 0, success: 0, failed: 0, unregistered: 0, errors: nil, duration: nil) }
            throw APIError.serverError(resp.message ?? "广播失败")
        }
        return data
    }

    func errorCodes() async throws -> [APNsErrorCode] {
        let resp: APIResponse<[APNsErrorCode]> = try await api.request("/push/error-codes")
        return resp.data ?? []
    }

    // MARK: - Device Registration

    func registerDevice(
        token: String, platform: String = "ios", sandbox: Bool = false,
        label: String? = nil, deviceName: String? = nil, model: String? = nil,
        osVersion: String? = nil, appVersion: String? = nil, reportedAt: String? = nil
    ) async throws {
        struct Body: Encodable {
            let device_token: String; let platform: String; let sandbox: Bool; let label: String?
            let device_name: String?; let model: String?
            let os_version: String?; let app_version: String?
            let reported_at: String?
        }
        let resp = try await api.requestRaw(
            "/push/register-device", method: "POST",
            body: Body(
                device_token: token, platform: platform, sandbox: sandbox, label: label,
                device_name: deviceName, model: model,
                os_version: osVersion, app_version: appVersion,
                reported_at: reportedAt
            )
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "注册设备 Token 失败") }
    }

    func unregisterDevice(token: String) async throws {
        struct Body: Encodable { let device_token: String }
        let resp = try await api.requestRaw("/push/unregister-device", method: "DELETE", body: Body(device_token: token))
        if !resp.success { throw APIError.serverError(resp.message ?? "注销设备 Token 失败") }
    }

    // MARK: - Device Management

    func registeredDevices() async throws -> [PushDevice] {
        let resp: APIResponse<[PushDevice]> = try await api.request("/push/devices")
        return resp.data ?? []
    }

    func getDevice(id: Int) async throws -> PushDevice {
        let resp: APIResponse<PushDevice> = try await api.request("/push/devices/\(id)")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func deleteDevice(id: Int) async throws {
        let resp = try await api.requestRaw("/push/devices/\(id)", method: "DELETE")
        if !resp.success { throw APIError.serverError(resp.message ?? "删除设备失败") }
    }

    func batchDeleteDevices(ids: [Int]) async throws {
        struct Body: Encodable { let ids: [Int] }
        let resp = try await api.requestRaw("/push/devices/batch-delete", method: "POST", body: Body(ids: ids))
        if !resp.success { throw APIError.serverError(resp.message ?? "批量删除失败") }
    }

    func batchUpdateDevices(ids: [Int], sandbox: Bool? = nil, label: String? = nil) async throws -> Int {
        struct Body: Encodable { let ids: [Int]; let sandbox: Bool?; let label: String? }
        struct Result: Decodable { let updated: Int? }
        let resp: APIResponse<Result> = try await api.request(
            "/push/devices/batch-update", method: "POST",
            body: Body(ids: ids, sandbox: sandbox, label: label)
        )
        return resp.data?.updated ?? 0
    }

    // MARK: - Device Registration History

    func deviceHistory(deviceToken: String? = nil, action: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> (items: [DeviceRegisterHistory], total: Int) {
        var path = "/push/device-history?limit=\(limit)&offset=\(offset)"
        if let t = deviceToken { path += "&device_token=\(t)" }
        if let a = action { path += "&action=\(a)" }
        let resp: DeviceHistoryResponse = try await api.request(path)
        return (resp.data ?? [], resp.total?.value ?? 0)
    }

    func deviceHistoryDetail(id: Int) async throws -> DeviceRegisterHistory {
        let resp: APIResponse<DeviceRegisterHistory> = try await api.request("/push/device-history/\(id)")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func addDevice(token: String, platform: String = "ios", sandbox: Bool = false, label: String? = nil, remark: String? = nil) async throws {
        struct Body: Encodable {
            let device_token: String; let platform: String; let sandbox: Bool; let label: String?; let remark: String?
        }
        let resp = try await api.requestRaw(
            "/push/devices/add", method: "POST",
            body: Body(device_token: token, platform: platform, sandbox: sandbox, label: label, remark: remark)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "添加设备失败") }
    }

    func updateDevice(id: Int, label: String?, sandbox: Bool?, remark: String? = nil) async throws {
        struct Body: Encodable { let label: String?; let sandbox: Bool?; let remark: String? }
        let resp = try await api.requestRaw("/push/devices/\(id)", method: "PUT", body: Body(label: label, sandbox: sandbox, remark: remark))
        if !resp.success { throw APIError.serverError(resp.message ?? "更新设备失败") }
    }

    func cleanupDevices(bundleId: String, pushKeyId: String? = nil) async throws -> (valid: Int, removed: Int, errored: Int) {
        struct Body: Encodable { let bundle_id: String; let push_key_id: String? }
        struct Result: Decodable { let valid: Int?; let removed: Int?; let errored: Int? }
        let resp: APIResponse<Result> = try await api.request(
            "/push/devices/cleanup", method: "POST",
            body: Body(bundle_id: bundleId, push_key_id: pushKeyId)
        )
        let d = resp.data
        return (d?.valid ?? 0, d?.removed ?? 0, d?.errored ?? 0)
    }

    func validateDevice(id: Int, bundleId: String? = nil, pushKeyId: String? = nil) async throws -> DeviceValidateResult {
        struct Body: Encodable { let bundle_id: String?; let push_key_id: String? }
        let resp: APIResponse<DeviceValidateResult> = try await api.request(
            "/push/devices/\(id)/validate", method: "POST",
            body: Body(bundle_id: bundleId, push_key_id: pushKeyId)
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func validateAllDevices(bundleId: String? = nil, pushKeyId: String? = nil) async throws -> DeviceValidateAllResult {
        struct Body: Encodable { let bundle_id: String?; let push_key_id: String? }
        let resp: APIResponse<DeviceValidateAllResult> = try await api.request(
            "/push/devices/validate-all", method: "POST",
            body: Body(bundle_id: bundleId, push_key_id: pushKeyId)
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func deviceStats() async throws -> PushDeviceStats {
        let resp: APIResponse<PushDeviceStats> = try await api.request("/push/devices-stats")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    // MARK: - Push History

    func listHistory(page: Int = 1, limit: Int = 20, type: String? = nil, status: String? = nil) async throws -> (items: [PushHistoryItem], total: Int) {
        var q = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "\(limit)")]
        if let type { q.append(URLQueryItem(name: "type", value: type)) }
        if let status { q.append(URLQueryItem(name: "status", value: status)) }
        struct Resp: Decodable { let success: Bool; let data: [PushHistoryItem]?; let total: FlexInt? }
        let resp: Resp = try await api.request("/push/history", queryItems: q)
        return (resp.data ?? [], resp.total?.value ?? 0)
    }

    func historyStats() async throws -> PushHistoryStats {
        let resp: APIResponse<PushHistoryStats> = try await api.request("/push/history/stats")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func getHistoryItem(id: Int) async throws -> PushHistoryItem {
        let resp: APIResponse<PushHistoryItem> = try await api.request("/push/history/\(id)")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func deleteHistoryItem(id: Int) async throws {
        let resp = try await api.requestRaw("/push/history/\(id)", method: "DELETE")
        if !resp.success { throw APIError.serverError(resp.message ?? "删除记录失败") }
    }

    func clearHistory(beforeDays: Int? = nil) async throws {
        struct Body: Encodable { let before_days: Int? }
        let resp = try await api.requestRaw("/push/history/clear", method: "POST", body: Body(before_days: beforeDays))
        if !resp.success { throw APIError.serverError(resp.message ?? "清理历史失败") }
    }

    func resendHistory(id: Int) async throws -> ResendResult {
        let resp: APIResponse<ResendResult> = try await api.request("/push/history/\(id)/resend", method: "POST")
        if let data = resp.data { return data }
        if resp.success { return ResendResult(success: true, message: resp.message) }
        throw APIError.serverError(resp.message ?? "重发失败")
    }

    // MARK: - Scheduled Pushes

    func listScheduled(page: Int = 1, status: String? = nil) async throws -> (items: [ScheduledPush], total: Int) {
        var q = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "20")]
        if let status { q.append(URLQueryItem(name: "status", value: status)) }
        struct Resp: Decodable { let success: Bool; let data: [ScheduledPush]?; let total: FlexInt? }
        let resp: Resp = try await api.request("/push/scheduled", queryItems: q)
        return (resp.data ?? [], resp.total?.value ?? 0)
    }

    func createScheduled(_ item: ScheduledPushCreate) async throws {
        let resp = try await api.requestRaw("/push/scheduled", method: "POST", body: item)
        if !resp.success { throw APIError.serverError(resp.message ?? "创建定时推送失败") }
    }

    func cancelScheduled(id: Int) async throws {
        let resp = try await api.requestRaw("/push/scheduled/\(id)/cancel", method: "POST")
        if !resp.success { throw APIError.serverError(resp.message ?? "取消定时推送失败") }
    }

    func deleteScheduled(id: Int) async throws {
        let resp = try await api.requestRaw("/push/scheduled/\(id)", method: "DELETE")
        if !resp.success { throw APIError.serverError(resp.message ?? "删除定时推送失败") }
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
    var bundle_id: String?
    var title: String
    var body: String
    var badge: Int?
    var sound: String?
    var sandbox: Bool
    var custom_data: [String: String]?
    var thread_id: String?
    var collapse_id: String?
    var mutable_content: Bool?
    var interruption_level: String?
    var relevance_score: Double?
    var priority: Int?
    var expiration: String?
}

struct PushResult: Decodable {
    let apns_id: String?
    let status: AnyCodableValue?
    let reason: String?
    let reason_cn: String?

    var statusText: String {
        switch status {
        case .int(let v): return "\(v)"
        case .string(let v): return v
        case .none: return "unknown"
        }
    }

    var isSuccess: Bool {
        switch status {
        case .int(let v): return v == 200
        case .string(let v): return v == "200" || v.lowercased() == "success"
        case .none: return false
        }
    }
}

enum AnyCodableValue: Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        throw DecodingError.typeMismatch(AnyCodableValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
    }
}

/// PostgreSQL COUNT/SUM may return string or int; this handles both.
struct FlexInt: Decodable {
    let value: Int

    init(_ v: Int) { value = v }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Int.self) { value = v; return }
        if let s = try? container.decode(String.self), let v = Int(s) { value = v; return }
        value = 0
    }
}

extension FlexInt: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self.value = value }
}

struct BroadcastRequest: Encodable {
    var push_key_id: String?
    var account_id: String?
    var team_id: String?
    var title: String
    var body: String?
    var badge: Int?
    var sound: String?
    var bundle_id: String?
    var sandbox: Bool?
    var custom_data: [String: String]?
    var thread_id: String?
    var collapse_id: String?
    var mutable_content: Bool?
    var interruption_level: String?
    var relevance_score: Double?
    var priority: Int?
    var expiration: String?
    var test_group_id: String?
}

struct BroadcastResult: Decodable {
    let total: FlexInt?
    let success: FlexInt?
    let failed: FlexInt?
    let unregistered: FlexInt?
    let errors: [BroadcastError]?
    let duration: FlexInt?
}

struct BroadcastError: Decodable, Identifiable {
    let token: String?
    let reason: String?
    let reason_cn: String?
    var id: String { (token ?? "") + (reason ?? "") }
}

struct PushDevice: Decodable, Identifiable {
    let id: Int?
    let user_id: String?
    let device_token: String?
    let platform: String?
    let sandbox: Bool?
    let label: String?
    let remark: String?
    let device_name: String?
    let model: String?
    let os_version: String?
    let app_version: String?
    let created_at: String?
    let username: String?

    var stableId: String { "\(id ?? 0)" }
    var displayToken: String {
        guard let t = device_token, t.count > 16 else { return device_token ?? "-" }
        return "\(t.prefix(8))...\(t.suffix(8))"
    }
    var envLabel: String { sandbox == true ? "沙盒" : "生产" }
    var envColor: Color {
        sandbox == true ? Color(red: 0.95, green: 0.60, blue: 0.07) : Color(red: 0.20, green: 0.78, blue: 0.35)
    }
}

struct DeviceRegisterHistory: Decodable, Identifiable {
    let id: Int?
    let device_token: String?
    let user_id: String?
    let username: String?
    let action: String?
    let platform: String?
    let sandbox: Bool?
    let label: String?
    let remark: String?
    let device_name: String?
    let model: String?
    let os_version: String?
    let app_version: String?
    let created_at: String?

    var stableId: String { "\(id ?? 0)" }
    var displayToken: String {
        guard let t = device_token, t.count > 16 else { return device_token ?? "-" }
        return "\(t.prefix(8))...\(t.suffix(8))"
    }
    var actionLabel: String {
        switch action {
        case "register": return "注册"
        case "report": return "上报"
        case "unregister": return "注销"
        case "invalidated": return "失效"
        default: return action ?? "未知"
        }
    }
    var displayTitle: String {
        if let rk = remark, !rk.isEmpty { return rk }
        if let name = device_name, !name.isEmpty { return name }
        return "未知设备"
    }
}

struct DeviceHistoryResponse: Decodable {
    let data: [DeviceRegisterHistory]?
    let total: FlexInt?
}

struct DeviceValidateResult: Decodable {
    let valid: Bool
    let status: Int?
    let reason: String?
    let reason_cn: String?
    let device_id: Int?
    let device_token: String?
    let device_name: String?
    let model: String?
}

struct DeviceValidateAllResult: Decodable {
    let total: FlexInt?
    let valid: FlexInt?
    let invalid: FlexInt?
    let results: [DeviceValidateItem]?
}

struct DeviceValidateItem: Decodable, Identifiable {
    let device_id: Int?
    let device_token: String?
    let device_name: String?
    let model: String?
    let sandbox: Bool?
    let valid: Bool
    let status: Int?
    let reason: String?
    let reason_cn: String?
    
    var id: Int { device_id ?? 0 }
    
    var displayToken: String {
        guard let t = device_token, t.count > 12 else { return device_token ?? "—" }
        return "\(t.prefix(6))...\(t.suffix(6))"
    }
}

struct PushSettings: Codable {
    var push_enabled: String?
    var default_push_key_id: String?
    var default_bundle_id: String?
    var default_sandbox: String?
    var apns_expiration: String?
    var apns_priority: String?
    var max_concurrency: String?
    var auto_cleanup_enabled: String?
    var history_retention_days: String?
    var tf_auto_push_enabled: String?
    var tf_auto_push_title: String?
    var tf_auto_push_body: String?
    var tf_auto_push_group_id: String?
    var tf_auto_push_bundle_id: String?

    var isEnabled: Bool { push_enabled == "true" }
}

struct PushStatus: Decodable {
    let push_enabled: Bool?
    let connections: [String: String]?
    let device_count: Int?
    let key_count: Int?
    let default_push_key_id: String?
    let default_bundle_id: String?
    let default_sandbox: Bool?
}

struct PushDeviceStats: Decodable {
    let total: FlexInt?
    let sandbox: FlexInt?
    let production: FlexInt?
    let ios: FlexInt?
}

struct PushHistoryItem: Decodable, Identifiable {
    let id: Int?
    let type: String?
    let title: String?
    let body: String?
    let bundle_id: String?
    let sandbox: Bool?
    let device_token: String?
    let apns_id: String?
    let target_count: FlexInt?
    let success_count: FlexInt?
    let failed_count: FlexInt?
    let unregistered_count: FlexInt?
    let status: String?
    let duration_ms: FlexInt?
    let created_at: String?
    let username: String?
    let user_id: String?
    let errors: [PushErrorItem]?

    var stableId: String { "\(id ?? 0)" }
    var typeLabel: String { type == "broadcast" ? "广播" : "单推" }
    var statusLabel: String {
        switch status {
        case "success": return "成功"
        case "partial": return "部分成功"
        case "failed": return "失败"
        default: return status ?? "未知"
        }
    }
}

struct PushErrorItem: Decodable, Identifiable {
    let token: String?
    let error: String?
    let status: Int?
    let reason: String?

    var id: String { token ?? UUID().uuidString }
}

struct ScheduledPush: Decodable, Identifiable {
    let id: Int?
    let user_id: String?
    let type: String?
    let title: String?
    let body: String?
    let bundle_id: String?
    let sandbox: Bool?
    let device_token: String?
    let push_key_id: String?
    let scheduled_at: String?
    let status: String?
    let result: ScheduledPushResult?
    let created_at: String?
    let executed_at: String?
    let username: String?

    var stableId: String { "\(id ?? 0)" }
    var typeLabel: String { type == "broadcast" ? "广播" : "单推" }
    var statusLabel: String {
        switch status {
        case "pending": return "待执行"
        case "executing": return "执行中"
        case "success": return "成功"
        case "partial": return "部分成功"
        case "failed": return "失败"
        case "cancelled": return "已取消"
        default: return status ?? "未知"
        }
    }
}

struct ScheduledPushResult: Decodable {
    let total: Int?
    let success: Int?
    let failed: Int?
    let error: String?
    let apns_id: String?
    let status: Int?
    let reason: String?
}

struct ScheduledPushCreate: Encodable {
    var type: String = "broadcast"
    var title: String
    var body: String?
    var bundle_id: String?
    var sandbox: Bool?
    var device_token: String?
    var push_key_id: String?
    var custom_data: [String: String]?
    var scheduled_at: String
}

struct PushHistoryStats: Decodable {
    let total_pushes: FlexInt?
    let today_pushes: FlexInt?
    let total_delivered: FlexInt?
    let total_failed: FlexInt?
    let broadcasts: FlexInt?
    let singles: FlexInt?
}

struct ResendResult: Decodable {
    let success: Bool?
    let message: String?
    let apns_id: String?
    let status: AnyCodableValue?
    let total: FlexInt?
    let reason_cn: String?

    init(success: Bool, message: String?) {
        self.success = success; self.message = message
        self.apns_id = nil; self.status = nil; self.total = nil; self.reason_cn = nil
    }
}
