import Foundation

struct CertCheckError: Decodable {
    let file: String?
    let error: String?
}

struct CertCheckResponse: Decodable {
    let p12_results: [P12Result]?
    let profile_results: [ProfileResult]?
    let matches: [CertProfileMatch]?
    let errors: [CertCheckError]?

    private enum CodingKeys: String, CodingKey {
        case p12_results, profile_results, matches, errors
        case p12, profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        p12_results = try container.decodeIfPresent([P12Result].self, forKey: .p12_results)
            ?? container.decodeIfPresent([P12Result].self, forKey: .p12)
        profile_results = try container.decodeIfPresent([ProfileResult].self, forKey: .profile_results)
            ?? container.decodeIfPresent([ProfileResult].self, forKey: .profiles)
        matches = try container.decodeIfPresent([CertProfileMatch].self, forKey: .matches)
        if let objectErrors = try? container.decodeIfPresent([CertCheckError].self, forKey: .errors) {
            errors = objectErrors
        } else if let stringErrors = try? container.decodeIfPresent([String].self, forKey: .errors) {
            errors = stringErrors.map { CertCheckError(file: nil, error: $0) }
        } else {
            errors = nil
        }
    }
}

struct P12Result: Decodable, Identifiable {
    let file: String?
    let valid: Bool?
    let status_text: String?
    let type: String?
    let has_private_key: Bool?
    let password_used: String?
    let cert_count: Int?
    let not_before: String?
    let not_after: String?
    let subject: CertSubject?
    let issuer: CertSubject?
    let is_expired: Bool?
    let apple_status: String?
    let apple_status_text: String?

    var id: String { file ?? UUID().uuidString }
}

struct CertSubject: Decodable {
    let CN: String?
    let O: String?
    let OU: String?
    let C: String?
}

struct ProfileResult: Decodable, Identifiable {
    let file: String?
    let valid: Bool?
    let name: String?
    let type: String?
    let bundle_id: String?
    let team_name: String?
    let team_id: String?
    let uuid: String?
    let device_count: Int?
    let provisions_all_devices: Bool?
    let creation_date: String?
    let expiration_date: String?
    let is_expired: Bool?
    let apple_status: String?
    let apple_status_text: String?
    let devices: [String]?

    var id: String { file ?? UUID().uuidString }
}

struct CertProfileMatch: Decodable, Identifiable {
    let bundle_id: String?
    let cert_type: String?
    let profile_type: String?
    let cert_expired: Bool?
    let profile_expired: Bool?
    let both_valid: Bool?
    let summary: String?

    var id: String { (bundle_id ?? "") + (cert_type ?? "") }
}
