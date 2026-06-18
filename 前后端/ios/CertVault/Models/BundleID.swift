import Foundation

struct BundleIDItem: Codable, Identifiable {
    let id: String
    let name: String?
    let identifier: String?
    let platform: String?
    let account_id: String?
    let apple_id: String?
    let created_at: String?

    var displayName: String { name ?? identifier ?? "未命名" }
}

struct BundleIDResources: Decodable {
    let devices: [Device]?
    let certificates: [Certificate]?
    let profiles: [Profile]?
}
