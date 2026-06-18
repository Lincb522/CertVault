import Foundation

struct HealthService {
    private let api = APIClient.shared

    func localCheck() async throws -> HealthCheckResult {
        let resp: APIResponse<HealthCheckResult> = try await api.request("/healthcheck/local")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func remoteCheck(accountId: String) async throws -> HealthCheckResult {
        let resp: APIResponse<HealthCheckResult> = try await api.request(
            "/healthcheck/remote",
            queryItems: [URLQueryItem(name: "account_id", value: accountId)]
        )
        guard let data = resp.data else { throw APIError.noData }
        return data
    }
}
