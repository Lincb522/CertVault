import Foundation

struct DashboardData: Decodable {
    let stats: DashboardStats
    let recent_certificates: [RecentCertificate]?
    let recent_devices: [RecentDevice]?
}

struct DashboardStats: Decodable {
    let accounts: Int
    let devices: Int
    let certificates: Int
    let certs_with_p12: Int?
    let profiles: Int
    let bundle_ids: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accounts = Self.decodeFlexInt(c, .accounts)
        devices = Self.decodeFlexInt(c, .devices)
        certificates = Self.decodeFlexInt(c, .certificates)
        certs_with_p12 = Self.decodeFlexIntOptional(c, .certs_with_p12)
        profiles = Self.decodeFlexInt(c, .profiles)
        bundle_ids = Self.decodeFlexIntOptional(c, .bundle_ids)
    }

    private enum CodingKeys: String, CodingKey {
        case accounts, devices, certificates, certs_with_p12, profiles, bundle_ids
    }

    private static func decodeFlexInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
        return 0
    }

    private static func decodeFlexIntOptional(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
        return nil
    }
}

struct RecentCertificate: Decodable, Identifiable {
    let id: String
    let name: String?
    let type: String?
    let expires_at: String?
    let created_at: String?
}

struct RecentDevice: Decodable, Identifiable {
    let id: String
    let name: String?
    let udid: String?
    let platform: String?
    let created_at: String?
}
