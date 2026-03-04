import Foundation

struct UDIDRequestResponse: Decodable {
    let request_id: String
}

struct UDIDResult: Decodable {
    let status: String?
    let udid: String?
    let product: String?
    let version: String?
    let serial: String?
    let imei: String?
    let device_name: String?
}

struct HealthCheckResult: Decodable {
    let summary: HealthSummary?
    let issues: [HealthIssue]?
    let certificates: [HealthCertInfo]?
    let profiles: [HealthProfileInfo]?
    let bundle_ids: [HealthBundleInfo]?
    let capabilities: [HealthCapabilityInfo]?
    let api_status: String?
}

struct HealthSummary: Decodable {
    let critical: Int?
    let warning: Int?
    let info: Int?
    let ok: Int?
}

struct HealthIssue: Decodable, Identifiable {
    let severity: String?
    let message: String?
    let suggestion: String?
    let type: String?

    var level: String? { severity }
    var detail: String? { suggestion }
    var id: String { (severity ?? "") + (message ?? "") + (suggestion ?? "") }
}

struct HealthCertInfo: Decodable, Identifiable {
    let _id: String?
    let apple_id: String?
    let name: String?
    let type: String?
    let expires_at: String?
    let status: String?
    let label: String?
    let days_left: Int?

    var id: String { _id ?? apple_id ?? name ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case apple_id, name, type, expires_at, status, label, days_left
    }
}

struct HealthProfileInfo: Decodable, Identifiable {
    let _id: String?
    let apple_id: String?
    let name: String?
    let type: String?
    let expires_at: String?
    let status: String?
    let state: String?
    let label: String?
    let days_left: Int?

    var id: String { _id ?? apple_id ?? name ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case apple_id, name, type, expires_at, status, state, label, days_left
    }
}

struct HealthBundleInfo: Decodable, Identifiable {
    let _id: String?
    let name: String?
    let identifier: String?
    let capabilities: [String]?

    var id: String { _id ?? identifier ?? name ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case name, identifier, capabilities
    }
}

struct HealthCapabilityInfo: Decodable, Identifiable {
    let bundle_id: String?
    let identifier: String?
    let name: String?
    let enabled_count: Int?
    let capabilities: [String]?
    let has_push: Bool?
    let has_sign_in: Bool?

    var id: String { bundle_id ?? identifier ?? UUID().uuidString }
}
