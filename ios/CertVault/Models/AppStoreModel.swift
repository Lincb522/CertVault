import Foundation

struct AppStoreVersion: Decodable, Identifiable {
    let id: String
    let version: String?
    let state: String?
    let state_label: String?
    let platform: String?
    let release_type: String?
    let created_date: String?
    let localizations: [AppStoreLocalization]?

    var displayState: String { state_label ?? state ?? "未知" }

    var releaseTypeLabel: String {
        switch release_type {
        case "MANUAL": return "手动发布"
        case "AFTER_APPROVAL": return "审核通过后自动发布"
        case "SCHEDULED": return "定时发布"
        default: return release_type ?? "未知"
        }
    }
}

struct AppStoreLocalization: Decodable, Identifiable {
    let id: String
    let locale: String?
    let whats_new: String?
    let description: String?
    let keywords: String?
    let promotional_text: String?
    let marketing_url: String?
    let support_url: String?
}
