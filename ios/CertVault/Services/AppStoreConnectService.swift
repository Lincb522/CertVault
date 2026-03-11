import Foundation

struct AppStoreConnectService {
    private let api = APIClient.shared

    // MARK: - Apps

    func listApps(accountId: String) async throws -> [AppItem] {
        let resp: APIResponse<[AppItem]> = try await api.request(
            "/apps/list", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func getApp(id: String, accountId: String) async throws -> AppItem {
        let resp: APIResponse<AppItem> = try await api.request(
            "/apps/\(id)", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func listBuilds(appId: String, accountId: String) async throws -> [AppBuild] {
        let resp: APIResponse<[AppBuild]> = try await api.request(
            "/apps/\(appId)/builds", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func listVersions(appId: String, accountId: String) async throws -> [AppVersion] {
        let resp: APIResponse<[AppVersion]> = try await api.request(
            "/apps/\(appId)/versions", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    // MARK: - TestFlight

    func listGroups(accountId: String, appId: String? = nil) async throws -> [BetaGroup] {
        var items = [URLQueryItem(name: "account_id", value: accountId)]
        if let appId { items.append(URLQueryItem(name: "app_id", value: appId)) }
        let resp: APIResponse<[BetaGroup]> = try await api.request("/testflight/groups", queryItems: items)
        return resp.data ?? []
    }

    struct GroupSettingsUpdate: Encodable {
        let account_id: String
        var name: String?
        var public_link_enabled: Bool?
        var public_link_limit: Int?
        var public_link_limit_enabled: Bool?
        var feedback_enabled: Bool?
        var has_access_to_all_builds: Bool?
    }

    func updateGroup(groupId: String, accountId: String, settings: GroupSettingsUpdate) async throws {
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)",
            method: "PUT",
            body: settings
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新测试组失败") }
    }

    // MARK: - Beta Recruitment Criteria (Device Conditions)

    struct DeviceCriteriaBody: Encodable {
        let account_id: String
        var device_families: [String]?
        var min_os_version: String?
        var require_device_check: Bool?
    }

    func getDeviceCriteria(groupId: String, accountId: String) async throws -> RecruitmentCriteria? {
        struct Resp: Decodable { let success: Bool; let data: RecruitmentCriteria? }
        let resp: Resp = try await api.request(
            "/testflight/groups/\(groupId)/criteria",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data
    }

    func createDeviceCriteria(groupId: String, accountId: String, body: DeviceCriteriaBody) async throws {
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)/criteria", method: "POST", body: body
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "设置设备条件失败") }
    }

    func updateDeviceCriteria(groupId: String, accountId: String, body: DeviceCriteriaBody) async throws {
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)/criteria", method: "PUT", body: body
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新设备条件失败") }
    }

    func deleteDeviceCriteria(groupId: String, accountId: String) async throws {
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)/criteria", method: "DELETE",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "删除设备条件失败") }
    }

    func getGroupDetail(groupId: String, accountId: String) async throws -> BetaGroupDetail {
        let resp: APIResponse<BetaGroupDetail> = try await api.request(
            "/testflight/groups/\(groupId)",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func createGroup(accountId: String, appId: String, name: String, isInternal: Bool) async throws {
        struct Body: Encodable {
            let account_id: String
            let app_id: String
            let name: String
            let is_internal: Bool
        }
        let resp = try await api.requestRaw(
            "/testflight/groups", method: "POST",
            body: Body(account_id: accountId, app_id: appId, name: name, is_internal: isInternal)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "创建分组失败") }
    }

    func deleteGroup(id: String, accountId: String) async throws {
        let resp = try await api.requestRaw(
            "/testflight/groups/\(id)",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "删除分组失败") }
    }

    func listTesters(accountId: String) async throws -> [BetaTester] {
        let resp: APIResponse<[BetaTester]> = try await api.request(
            "/testflight/testers", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func createTester(accountId: String, email: String, firstName: String, lastName: String, groupIds: [String] = []) async throws {
        struct Body: Encodable {
            let account_id: String
            let email: String
            let first_name: String
            let last_name: String
            let group_ids: [String]
        }
        let resp = try await api.requestRaw(
            "/testflight/testers", method: "POST",
            body: Body(account_id: accountId, email: email, first_name: firstName, last_name: lastName, group_ids: groupIds)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "添加测试员失败") }
    }

    func deleteTester(id: String, accountId: String) async throws {
        let resp = try await api.requestRaw(
            "/testflight/testers/\(id)",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "删除测试员失败") }
    }

    func groupTesters(groupId: String, accountId: String) async throws -> [BetaTester] {
        let resp: APIResponse<[BetaTester]> = try await api.request(
            "/testflight/groups/\(groupId)/testers",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    // MARK: - Build Detail

    func getBuildDetail(buildId: String, accountId: String) async throws -> BuildDetail {
        let resp: APIResponse<BuildDetail> = try await api.request(
            "/testflight/builds/\(buildId)",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func updateBuildLocalization(buildId: String, accountId: String, whatsNew: String, locale: String) async throws {
        struct Body: Encodable {
            let account_id: String
            let whats_new: String
            let locale: String
        }
        let resp = try await api.requestRaw(
            "/testflight/builds/\(buildId)/localizations", method: "PUT",
            body: Body(account_id: accountId, whats_new: whatsNew, locale: locale)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新测试内容失败") }
    }

    // MARK: - Version Build & Phased Release

    func getVersionBuild(versionId: String, accountId: String) async throws -> VersionBuildInfo? {
        let resp: APIResponse<VersionBuildInfo?> = try await api.request(
            "/appstore/versions/\(versionId)/build",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? nil
    }

    func setVersionBuild(versionId: String, accountId: String, buildId: String?) async throws {
        struct Body: Encodable {
            let account_id: String
            let build_id: String?
        }
        let resp = try await api.requestRaw(
            "/appstore/versions/\(versionId)/build", method: "PATCH",
            body: Body(account_id: accountId, build_id: buildId)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "关联构建失败") }
    }

    func updateVersionReleaseType(versionId: String, accountId: String, releaseType: String, earliestReleaseDate: String? = nil) async throws {
        struct Body: Encodable {
            let account_id: String
            let release_type: String
            let earliest_release_date: String?
        }
        let resp = try await api.requestRaw(
            "/appstore/versions/\(versionId)", method: "PATCH",
            body: Body(account_id: accountId, release_type: releaseType, earliest_release_date: earliestReleaseDate)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新发布方式失败") }
    }

    func getPhasedRelease(versionId: String, accountId: String) async throws -> PhasedReleaseInfo? {
        let resp: APIResponse<PhasedReleaseInfo?> = try await api.request(
            "/appstore/versions/\(versionId)/phased-release",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? nil
    }

    func addBuildsToGroup(groupId: String, accountId: String, buildIds: [String], whatsNew: String? = nil, locale: String = "en-US") async throws {
        struct Body: Encodable {
            let account_id: String
            let build_ids: [String]
            let whats_new: String?
            let locale: String?
        }
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)/builds", method: "POST",
            body: Body(account_id: accountId, build_ids: buildIds, whats_new: whatsNew, locale: whatsNew != nil ? locale : nil)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "分发构建失败") }
    }

    // MARK: - Tester ↔ Group Management

    func addTestersToGroup(groupId: String, accountId: String, testerIds: [String]) async throws {
        struct Body: Encodable {
            let account_id: String
            let tester_ids: [String]
        }
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)/testers", method: "POST",
            body: Body(account_id: accountId, tester_ids: testerIds)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "添加测试员失败") }
    }

    func removeTestersFromGroup(groupId: String, accountId: String, testerIds: [String]) async throws {
        struct Body: Encodable {
            let account_id: String
            let tester_ids: [String]
        }
        let resp = try await api.requestRaw(
            "/testflight/groups/\(groupId)/testers", method: "DELETE",
            body: Body(account_id: accountId, tester_ids: testerIds)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "移除测试员失败") }
    }

    // MARK: - TestFlight Builds (global)

    func listTestFlightBuilds(accountId: String, appId: String? = nil) async throws -> [AppBuild] {
        var items = [URLQueryItem(name: "account_id", value: accountId)]
        if let appId { items.append(URLQueryItem(name: "app_id", value: appId)) }
        let resp: APIResponse<[AppBuild]> = try await api.request("/testflight/builds", queryItems: items)
        return resp.data ?? []
    }

    // MARK: - Beta App Review

    func submitForBetaReview(buildId: String, accountId: String) async throws {
        struct Body: Encodable { let account_id: String }
        let resp = try await api.requestRaw(
            "/testflight/builds/\(buildId)/submit-for-review",
            method: "POST",
            body: Body(account_id: accountId)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "提交 Beta 审核失败") }
    }

    func getBetaReviewStatus(buildId: String, accountId: String) async throws -> BetaReviewStatus? {
        struct Resp: Decodable {
            let success: Bool
            let data: BetaReviewStatus?
        }
        let resp: Resp = try await api.request(
            "/testflight/builds/\(buildId)/review-status",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data
    }

    // MARK: - Beta Review Info (App-level)

    func getBetaReviewInfo(appId: String, accountId: String) async throws -> BetaReviewInfo? {
        struct Resp: Decodable { let success: Bool; let data: BetaReviewInfo? }
        let resp: Resp = try await api.request(
            "/testflight/apps/\(appId)/review-info",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data
    }

    func updateBetaReviewInfo(appId: String, accountId: String, info: BetaReviewInfoUpdate) async throws {
        let resp = try await api.requestRaw(
            "/testflight/apps/\(appId)/review-info", method: "PUT", body: info
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新 Beta 审核信息失败") }
    }

    func getBetaLicense(appId: String, accountId: String) async throws -> BetaLicenseInfo? {
        struct Resp: Decodable { let success: Bool; let data: BetaLicenseInfo? }
        let resp: Resp = try await api.request(
            "/testflight/apps/\(appId)/license",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data
    }

    func updateBetaLicense(appId: String, accountId: String, text: String) async throws {
        struct Body: Encodable { let account_id: String; let agreement_text: String }
        let resp = try await api.requestRaw(
            "/testflight/apps/\(appId)/license", method: "PUT",
            body: Body(account_id: accountId, agreement_text: text)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新 Beta 许可协议失败") }
    }

    func updateBuildBetaDetail(buildId: String, accountId: String, autoNotify: Bool) async throws {
        struct Body: Encodable { let account_id: String; let auto_notify_enabled: Bool }
        let resp = try await api.requestRaw(
            "/testflight/builds/\(buildId)/beta-detail", method: "PUT",
            body: Body(account_id: accountId, auto_notify_enabled: autoNotify)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新构建设置失败") }
    }

    // MARK: - App Store Versions

    func listAppStoreVersions(accountId: String, appId: String) async throws -> [AppStoreVersion] {
        let resp: APIResponse<[AppStoreVersion]> = try await api.request(
            "/appstore/versions", queryItems: [
                URLQueryItem(name: "account_id", value: accountId),
                URLQueryItem(name: "app_id", value: appId),
            ]
        )
        return resp.data ?? []
    }

    func createAppStoreVersion(accountId: String, appId: String, version: String, platform: String) async throws {
        struct Body: Encodable {
            let account_id: String
            let app_id: String
            let version_string: String
            let platform: String
        }
        let resp = try await api.requestRaw(
            "/appstore/versions", method: "POST",
            body: Body(account_id: accountId, app_id: appId, version_string: version, platform: platform)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "创建版本失败") }
    }

    func getAppStoreVersion(id: String, accountId: String) async throws -> AppStoreVersion {
        let resp: APIResponse<AppStoreVersion> = try await api.request(
            "/appstore/versions/\(id)", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func submitForReview(versionId: String, accountId: String) async throws {
        struct Body: Encodable { let account_id: String }
        let resp = try await api.requestRaw(
            "/appstore/versions/\(versionId)/submit", method: "POST",
            body: Body(account_id: accountId)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "提交审核失败") }
    }

    func listVersionLocalizations(versionId: String, accountId: String) async throws -> [AppStoreLocalization] {
        let resp: APIResponse<[AppStoreLocalization]> = try await api.request(
            "/appstore/versions/\(versionId)/localizations",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func updateLocalization(id: String, accountId: String, whatsNew: String?, description: String?, keywords: String?, promotionalText: String? = nil, marketingUrl: String? = nil, supportUrl: String? = nil) async throws {
        struct Body: Encodable {
            let account_id: String
            let whats_new: String?
            let description: String?
            let keywords: String?
            let promotional_text: String?
            let marketing_url: String?
            let support_url: String?
        }
        let resp = try await api.requestRaw(
            "/appstore/localizations/\(id)", method: "PATCH",
            body: Body(account_id: accountId, whats_new: whatsNew, description: description, keywords: keywords, promotional_text: promotionalText, marketing_url: marketingUrl, support_url: supportUrl)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新本地化失败") }
    }

    // MARK: - Phased Release Management

    func createPhasedRelease(versionId: String, accountId: String) async throws {
        struct Body: Encodable { let account_id: String }
        let resp = try await api.requestRaw(
            "/appstore/versions/\(versionId)/phased-release", method: "POST",
            body: Body(account_id: accountId)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "启用分阶段发布失败") }
    }

    func updatePhasedRelease(id: String, accountId: String, state: String) async throws {
        struct Body: Encodable {
            let account_id: String
            let state: String
        }
        let resp = try await api.requestRaw(
            "/appstore/phased-release/\(id)", method: "PATCH",
            body: Body(account_id: accountId, state: state)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新分阶段发布失败") }
    }

    func deletePhasedRelease(id: String, accountId: String) async throws {
        struct Body: Encodable { let account_id: String }
        let resp = try await api.requestRaw(
            "/appstore/phased-release/\(id)", method: "DELETE",
            body: Body(account_id: accountId)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "取消分阶段发布失败") }
    }
}
