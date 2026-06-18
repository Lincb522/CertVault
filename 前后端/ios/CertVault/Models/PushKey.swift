import Foundation

struct PushKey: Codable, Identifiable {
    let id: String
    let name: String?
    let key_id: String?
    let team_id: String?
    let bundle_ids: String?
    let created_at: String?

    var displayName: String { name ?? "未命名密钥" }

    var pickerLabel: String {
        var parts: [String] = [displayName]
        if let kid = key_id, !kid.isEmpty { parts.append("Key: \(kid)") }
        if let tid = team_id, !tid.isEmpty { parts.append("Team: \(tid)") }
        return parts.joined(separator: " · ")
    }
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

    private let _stableId = UUID().uuidString
    var id: String { name ?? _stableId }

    enum CodingKeys: String, CodingKey {
        case name, config, url
    }
}
