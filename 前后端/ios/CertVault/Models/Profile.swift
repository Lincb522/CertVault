import Foundation

struct Profile: Codable, Identifiable {
    let id: String
    let name: String?
    let type: String?
    let profile_path: String?
    let has_file: Bool?
    let bundle_id: String?
    let account_id: String?
    let apple_id: String?
    let expires_at: String?
    let created_at: String?
    let status: String?

    var displayName: String { name ?? "未命名描述文件" }
}

struct ProfileDetail: Decodable {
    let id: String
    let name: String?
    let type: String?
    let profile_path: String?
    let has_file: Bool?
    let bundle_id: String?
    let account_id: String?
    let apple_id: String?
    let expires_at: String?
    let created_at: String?
    let devices: [ProfileLinkedDevice]?
    let bundle_info: ProfileBundleInfo?
    let certificates: [ProfileLinkedCert]?
}

struct ProfileLinkedDevice: Decodable, Identifiable {
    let id: String
    let name: String?
    let udid: String?
    let platform: String?
    let status: String?
    let model: String?
    let device_class: String?
    var displayName: String { name ?? "未命名设备" }
}

struct ProfileBundleInfo: Decodable {
    let id: String?
    let name: String?
    let identifier: String?
    let platform: String?
}

struct ProfileLinkedCert: Decodable, Identifiable {
    let id: String
    let name: String?
    let type: String?
    let expires_at: String?
}

struct ProfileType: Decodable, Identifiable {
    let value: String
    let label: String
    let desc: String?
    var id: String { value }
}
