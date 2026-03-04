import Foundation

struct PushKey: Decodable, Identifiable {
    let id: String
    let name: String?
    let key_id: String?
    let team_id: String?
    let bundle_ids: String?
    let created_at: String?

    var displayName: String { name ?? "未命名密钥" }
}

// MARK: - Push Guide

struct PushGuide: Decodable {
    let methods: [PushMethod]?
    let common_services: [PushCommonService]?
}

struct PushMethod: Decodable, Identifiable {
    let id: String
    let name: String?
    let desc: String?
    let pros: [String]?
    let cons: [String]?
    let steps: [String]?
}

struct PushCommonService: Decodable, Identifiable {
    let name: String?
    let config: String?
    let url: String?

    var id: String { name ?? UUID().uuidString }
}
