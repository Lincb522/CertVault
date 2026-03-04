import Foundation

struct Account: Codable, Identifiable {
    let id: String
    let name: String?
    let issuer_id: String?
    let key_id: String?
    let created_at: String?
    let remote_synced: Bool?
    let stats: AccountStats?
    let certificates: [Certificate]?
    let devices: [Device]?
    let bundle_ids: [BundleIDItem]?
    let profiles: [Profile]?

    enum CodingKeys: String, CodingKey {
        case id, name, issuer_id, key_id, created_at, remote_synced, stats
        case certificates, devices, bundle_ids, profiles
    }

    var displayName: String { name ?? "未命名账号" }
}

struct AccountStats: Codable {
    let certificates: Int?
    let devices: Int?
    let bundle_ids: Int?
    let profiles: Int?
}

struct TestConnectionResult: Decodable {
    let issuer_id: String?
    let key_id: String?
    let certificates_found: Int?
}
