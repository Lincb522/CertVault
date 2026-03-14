import Foundation

struct BetaGroup: Decodable, Identifiable {
    let id: String
    let name: String?
    let is_internal: Bool?
    let public_link_enabled: Bool?
    let public_link: String?
    let public_link_limit: Int?
    let created_date: String?
    let app_id: String?
    let app_name: String?
    let bundle_id: String?

    var displayName: String { name ?? "未命名分组" }
    var typeLabel: String { (is_internal == true) ? "内部" : "外部" }
    var groupLabel: String {
        if let appName = app_name, !appName.isEmpty {
            return "\(displayName) (\(appName))"
        }
        return displayName
    }
}

struct BetaGroupDetail: Decodable {
    let id: String
    let name: String?
    let is_internal: Bool?
    let public_link_enabled: Bool?
    let public_link: String?
    let public_link_limit: Int?
    let public_link_limit_enabled: Bool?
    let feedback_enabled: Bool?
    let has_access_to_all_builds: Bool?
    let created_date: String?
    let tester_count: Int?
    let build_count: Int?
    let testers: [BetaTester]?
    let builds: [AppBuild]?
    let recruitment_criteria: RecruitmentCriteria?

    var displayName: String { name ?? "未命名分组" }
    var typeLabel: String { (is_internal == true) ? "内部" : "外部" }
}

struct RecruitmentCriteria: Decodable {
    let id: String?
    let deviceFamilies: [String]?
    let minOsVersion: String?
    let requireDeviceCheck: Bool?
}

struct BetaTester: Decodable, Identifiable {
    let id: String
    let email: String?
    let first_name: String?
    let last_name: String?
    let invite_type: String?
    let state: String?

    var displayName: String {
        let parts = [first_name, last_name].compactMap { $0 }.joined(separator: " ")
        return parts.isEmpty ? (email ?? "未知") : parts
    }

    var stateLabel: String {
        switch state {
        case "ACCEPTED": return "已接受"
        case "INVITED": return "已邀请"
        case "NOT_INVITED": return "未邀请"
        case "REVOKED": return "已撤销"
        default: return state ?? "未知"
        }
    }
}
