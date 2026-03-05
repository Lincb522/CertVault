import Foundation

struct CapabilityItem: Decodable, Identifiable {
    let _serverId: String?
    let type: String
    let name: String?
    let enabled: Bool?

    var id: String { _serverId ?? type }
    var isEnabled: Bool { enabled == true }

    enum CodingKeys: String, CodingKey {
        case _serverId = "id"
        case type, name, enabled
    }
}

struct AvailableCapability: Decodable, Identifiable {
    let type: String
    let name: String
    let category: String?
    let description: String?
    let requirements: String?
    var id: String { type }
}

struct CapabilityPreset: Decodable, Identifiable {
    let name: String
    let capabilities: [String]
    var id: String { name }
}

struct AvailableCapabilitiesResponse: Decodable {
    let capabilities: [AvailableCapability]?
    let presets: [String: [String]]?
    let categories: [String: [String]]?
}
