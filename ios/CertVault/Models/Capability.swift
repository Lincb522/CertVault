import Foundation

struct CapabilityItem: Decodable, Identifiable {
    let id: String?
    let type: String
    let name: String?
    let enabled: Bool?

    var stableId: String { id ?? type }
    var isEnabled: Bool { enabled == true }
}

extension CapabilityItem {
    // Conform Identifiable using stableId
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
