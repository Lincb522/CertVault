import Foundation

struct Certificate: Decodable, Identifiable {
    let id: String
    let name: String?
    let type: String?
    let platform: String?
    let serial_number: String?
    let expires_at: String?
    let created_at: String?
    let p12_path: String?
    let password: String?
    let has_p12: Bool?
    let has_private_key: Bool?
    let cert_content: String?
    let account_id: String?
    let apple_id: String?
    let status: String?

    var displayName: String { name ?? "未命名证书" }
    var canDownloadP12: Bool { has_p12 == true || has_private_key == true }

    var isExpired: Bool {
        guard let expiresStr = expires_at else { return false }
        let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss"]
        for fmt in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            if let date = f.date(from: expiresStr) {
                return date < Date()
            }
        }
        return false
    }
}

struct CertificateType: Decodable, Identifiable {
    let value: String
    let label: String
    let desc: String?
    var id: String { value }
}

struct CertQuota: Decodable {
    let label: String?
    let used: Int
    let limit: Int
    let available: Int
}

struct CertQuotaResponse: Decodable {
    let total_certs: Int?
}

struct CertRelation: Decodable, Identifiable {
    let id: String
    let name: String?
    let type: String?
    let profiles: [RelatedProfile]?
}

struct RelatedProfile: Decodable, Identifiable {
    let id: String
    let name: String?
    let type: String?
}
