import Foundation

struct ProfileService {
    private let api = APIClient.shared

    func list(accountId: String) async throws -> [Profile] {
        let resp: APIResponse<[Profile]> = try await api.request(
            "/profiles", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func types() async throws -> [ProfileType] {
        let resp: APIResponse<[ProfileType]> = try await api.request("/profiles/types")
        return resp.data ?? []
    }

    func create(accountId: String, name: String, type: String, bundleId: String,
                certificateIds: [String], deviceIds: [String]) async throws -> Profile {
        struct Body: Encodable {
            let account_id: String
            let name: String
            let type: String
            let bundle_id: String
            let certificate_ids: [String]
            let device_ids: [String]
        }
        let resp: APIResponse<Profile> = try await api.request(
            "/profiles/create", method: "POST",
            body: Body(account_id: accountId, name: name, type: type,
                       bundle_id: bundleId, certificate_ids: certificateIds, device_ids: deviceIds)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "创建失败") }
        return data
    }

    func delete(id: String) async throws {
        _ = try await api.requestRaw("/profiles/\(id)", method: "DELETE")
    }

    func detail(id: String) async throws -> ProfileDetail {
        let resp: APIResponse<ProfileDetail> = try await api.request("/profiles/\(id)/detail")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    // Bundle IDs
    func bundleIds(accountId: String) async throws -> [BundleIDItem] {
        let resp: APIResponse<[BundleIDItem]> = try await api.request(
            "/profiles/bundle-ids", queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        return resp.data ?? []
    }

    func createBundleId(accountId: String, identifier: String, name: String, platform: String = "IOS") async throws -> BundleIDItem {
        struct Body: Encodable {
            let account_id: String
            let identifier: String
            let name: String
            let platform: String
        }
        let resp: APIResponse<BundleIDItem> = try await api.request(
            "/profiles/bundle-ids", method: "POST",
            body: Body(account_id: accountId, identifier: identifier, name: name, platform: platform)
        )
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "创建失败") }
        return data
    }

    func deleteBundleId(id: String) async throws {
        _ = try await api.requestRaw("/profiles/bundle-ids/\(id)", method: "DELETE")
    }

    func bundleIdResources(id: String) async throws -> BundleIDResources {
        let resp: APIResponse<BundleIDResources> = try await api.request("/profiles/bundle-ids/\(id)/resources")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }
}
