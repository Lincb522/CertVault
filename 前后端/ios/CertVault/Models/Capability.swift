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

    private struct PresetObject: Decodable {
        let label: String?
        let desc: String?
        let types: [String]
    }

    private enum CodingKeys: String, CodingKey {
        case capabilities, presets, categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        capabilities = try container.decodeIfPresent([AvailableCapability].self, forKey: .capabilities)
        categories = try container.decodeIfPresent([String: [String]].self, forKey: .categories)

        if let direct = try? container.decode([String: [String]].self, forKey: .presets) {
            presets = direct
        } else if let objectMap = try? container.decode([String: PresetObject].self, forKey: .presets) {
            presets = objectMap.mapValues { $0.types }
        } else {
            presets = nil
        }
    }
}
