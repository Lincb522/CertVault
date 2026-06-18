import Foundation

struct UDIDService {
    private let api = APIClient.shared

    func createRequest(accountId: String? = nil) async throws -> String {
        let body: [String: String]? = accountId.map { ["account_id": $0] }
        let resp: APIResponse<UDIDRequestResponse> = try await api.request("/udid/create-request", method: "POST", body: body)
        guard let data = resp.data else { throw APIError.serverError(resp.message ?? "创建请求失败") }
        return data.request_id
    }

    func enrollURL(requestId: String) -> String {
        var base = api.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        if base.hasPrefix("http://") {
            base = base.replacingOccurrences(of: "http://", with: "https://")
            if let portRange = base.range(of: #":\d+$"#, options: .regularExpression) {
                base.removeSubrange(portRange)
            }
        }
        return "\(base)/api/udid/enroll/\(requestId)?host=\(base)"
    }

    func result(requestId: String) async throws -> UDIDResult {
        let resp: APIResponse<UDIDResult> = try await api.request("/udid/result/\(requestId)")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }
}
