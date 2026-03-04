import Foundation

struct Device: Codable, Identifiable {
    let id: String
    let name: String?
    let udid: String?
    let platform: String?
    let status: String?
    let device_class: String?
    let model: String?
    let account_id: String?
    let apple_id: String?
    let created_at: String?
    let certificates: [Certificate]?
    let profiles: [Profile]?

    var displayName: String { name ?? "未命名设备" }
    var isEnabled: Bool { status?.uppercased() == "ENABLED" }
    var isIneligible: Bool {
        guard let s = status?.uppercased() else { return false }
        return s != "ENABLED" && s != "DISABLED"
    }
    var isDisabled: Bool { status?.uppercased() == "DISABLED" }
}

struct AutoBindRequest: Encodable {
    let account_id: String
    let name: String
    let udid: String
    let platform: String
    let bundle_identifier: String
    let bundle_name: String
    let cert_type: String
    let profile_type: String
    let password: String
}

struct AutoBindStep: Decodable {
    let step: String?
    let status: String?
    let message: String?
}

struct AutoBindResult: Decodable {
    let steps: [AutoBindStep]?
    let device: Device?
    let certificate: AutoBindCert?
    let bundle_id: BundleIDItem?
    let profile: AutoBindProfile?
}

struct AutoBindCert: Decodable {
    let id: String?
    let p12_path: String?
    let password: String?
}

struct AutoBindProfile: Decodable {
    let id: String?
    let profile_path: String?
}

struct DeviceResources: Decodable {
    let certificates: [Certificate]?
    let profiles: [Profile]?
}
