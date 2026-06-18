import Foundation

struct AppItem: Decodable, Identifiable {
    let id: String
    let name: String?
    let bundle_id: String?
    let sku: String?
    let primary_locale: String?
    let platform: String?

    var displayName: String { name ?? "未命名应用" }
}

struct AppBuild: Decodable, Identifiable, Hashable {
    let id: String
    let version: String?
    let app_version: String?
    let platform: String?
    let processing_state: String?
    let min_os_version: String?
    let uploaded_date: String?
    let expiration_date: String?
    let expired: Bool?
    let build_audience_type: String?
    let icon_url: String?
    let external_build_state: String?
    let internal_build_state: String?
    let auto_notify_enabled: Bool?

    var displayVersion: String {
        if let appVer = app_version, let build = version {
            return "\(appVer) (\(build))"
        }
        return "v\(version ?? "-")"
    }

    var stateLabel: String {
        switch processing_state {
        case "VALID": return "有效"
        case "PROCESSING": return "处理中"
        case "FAILED": return "失败"
        case "INVALID": return "无效"
        default: return processing_state ?? "未知"
        }
    }

    var externalStateLabel: String {
        switch external_build_state {
        case "PROCESSING": return "处理中"
        case "PROCESSING_EXCEPTION": return "处理异常"
        case "MISSING_EXPORT_COMPLIANCE": return "缺少出口合规"
        case "READY_FOR_BETA_TESTING": return "可测试"
        case "IN_BETA_TESTING": return "测试中"
        case "EXPIRED": return "已过期"
        case "READY_FOR_BETA_SUBMISSION": return "待提交审核"
        case "IN_EXPORT_COMPLIANCE_REVIEW": return "出口合规审核中"
        case "WAITING_FOR_BETA_REVIEW": return "等待审核"
        case "IN_BETA_REVIEW": return "审核中"
        case "BETA_REJECTED": return "审核被拒"
        case "BETA_APPROVED": return "审核通过"
        default: return external_build_state ?? "-"
        }
    }

    var internalStateLabel: String {
        switch internal_build_state {
        case "PROCESSING": return "处理中"
        case "PROCESSING_EXCEPTION": return "处理异常"
        case "MISSING_EXPORT_COMPLIANCE": return "缺少出口合规"
        case "READY_FOR_BETA_TESTING": return "可测试"
        case "IN_BETA_TESTING": return "测试中"
        case "EXPIRED": return "已过期"
        default: return internal_build_state ?? "-"
        }
    }

    var betaStateColor: (external: String, `internal`: String) {
        func color(_ state: String?) -> String {
            switch state {
            case "READY_FOR_BETA_TESTING", "IN_BETA_TESTING", "BETA_APPROVED": return "green"
            case "PROCESSING", "IN_EXPORT_COMPLIANCE_REVIEW", "WAITING_FOR_BETA_REVIEW", "IN_BETA_REVIEW": return "orange"
            case "EXPIRED", "BETA_REJECTED", "PROCESSING_EXCEPTION", "FAILED": return "red"
            case "READY_FOR_BETA_SUBMISSION", "MISSING_EXPORT_COMPLIANCE": return "blue"
            default: return "gray"
            }
        }
        return (color(external_build_state), color(internal_build_state))
    }
}

struct BetaReviewStatus: Decodable {
    let id: String?
    let beta_review_state: String?

    var stateLabel: String {
        switch beta_review_state {
        case "WAITING_FOR_REVIEW": return "等待审核"
        case "IN_REVIEW": return "审核中"
        case "REJECTED": return "被拒绝"
        case "APPROVED": return "已通过"
        default: return beta_review_state ?? "未知"
        }
    }
}

struct BuildDetail: Decodable {
    let id: String
    let version: String?
    let uploaded_date: String?
    let expiration_date: String?
    let expired: Bool?
    let processing_state: String?
    let min_os_version: String?
    let auto_notify_enabled: Bool?
    let external_build_state: String?
    let internal_build_state: String?
    let localizations: [BuildLocalization]?
    let groups: [BuildGroupInfo]?

    var stateLabel: String {
        switch processing_state {
        case "VALID": return "有效"
        case "PROCESSING": return "处理中"
        case "FAILED": return "失败"
        case "INVALID": return "无效"
        default: return processing_state ?? "未知"
        }
    }

    var externalStateLabel: String {
        switch external_build_state {
        case "PROCESSING": return "处理中"
        case "PROCESSING_EXCEPTION": return "处理异常"
        case "MISSING_EXPORT_COMPLIANCE": return "缺少出口合规"
        case "READY_FOR_BETA_TESTING": return "可测试"
        case "IN_BETA_TESTING": return "测试中"
        case "EXPIRED": return "已过期"
        case "READY_FOR_BETA_SUBMISSION": return "可提交 Beta 审核"
        case "IN_EXPORT_COMPLIANCE_REVIEW": return "出口合规审核中"
        case "WAITING_FOR_BETA_REVIEW": return "等待 Beta 审核"
        case "IN_BETA_REVIEW": return "Beta 审核中"
        case "BETA_REJECTED": return "Beta 被拒"
        case "BETA_APPROVED": return "Beta 已通过"
        default: return external_build_state ?? "-"
        }
    }
}

struct BuildLocalization: Decodable, Identifiable {
    let id: String
    let locale: String?
    let whats_new: String?
}

struct BuildGroupInfo: Decodable, Identifiable {
    let id: String
    let name: String?
    let is_internal: Bool?
}

struct BetaReviewInfo: Decodable {
    let id: String?
    let contact_email: String?
    let contact_first_name: String?
    let contact_last_name: String?
    let contact_phone: String?
    let demo_account_name: String?
    let demo_account_password: String?
    let demo_account_required: Bool?
    let notes: String?
}

struct BetaReviewInfoUpdate: Encodable {
    let account_id: String
    var contact_email: String?
    var contact_first_name: String?
    var contact_last_name: String?
    var contact_phone: String?
    var demo_account_name: String?
    var demo_account_password: String?
    var demo_account_required: Bool?
    var notes: String?
}

struct BetaLicenseInfo: Decodable {
    let id: String?
    let agreement_text: String?
}

struct VersionBuildInfo: Decodable {
    let id: String
    let version: String?
    let processing_state: String?
    let uploaded_date: String?
}

struct PhasedReleaseInfo: Decodable {
    let id: String
    let state: String?
    let start_date: String?
    let current_day_number: Int?
    let total_pause_duration: Int?

    var stateLabel: String {
        switch state {
        case "INACTIVE": return "未开始"
        case "ACTIVE": return "进行中"
        case "PAUSED": return "已暂停"
        case "COMPLETE": return "已完成"
        default: return state ?? "未知"
        }
    }
}

struct AppVersion: Decodable, Identifiable {
    let id: String
    let version: String?
    let state: String?
    let state_label: String?
    let platform: String?
    let release_type: String?
    let created_date: String?

    var displayState: String { state_label ?? state ?? "未知" }
}
