import Foundation

final class APIClient: ObservableObject {
    static let shared = APIClient()

    static let unauthorizedNotification = Notification.Name("APIClient.unauthorized")

    let baseURL = AppConstants.serverURL

    var token: String? {
        get { KeychainService.shared.get(forKey: AppConstants.tokenKey) }
        set {
            if let v = newValue {
                KeychainService.shared.save(v, forKey: AppConstants.tokenKey)
                AppLogger.auth.info("🔑 Token saved (len=\(v.count))")
            } else {
                KeychainService.shared.delete(forKey: AppConstants.tokenKey)
                AppLogger.auth.info("🔑 Token cleared")
            }
        }
    }

    var isLoggedIn: Bool { token != nil }

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
            for fmt in formats {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = fmt
                if let date = f.date(from: str) { return date }
            }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        AppLogger.api.info("🚀 APIClient init | baseURL=\(self.baseURL) | hasToken=\(self.isLoggedIn)")
    }

    // MARK: - Core Request

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let url = try buildURL(endpoint, queryItems: queryItems)
        var req = URLRequest(url: url)
        req.httpMethod = method
        injectAuth(&req)

        AppLogger.logRequest(method, endpoint: endpoint, body: body)

        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await session.data(for: req)
            let duration = CFAbsoluteTimeGetCurrent() - start

            if let httpResp = response as? HTTPURLResponse {
                AppLogger.logResponse(method, endpoint: endpoint, status: httpResp.statusCode, data: data, duration: duration)
            }

            try validateResponse(response, data: data)

            do {
                let decoded = try decoder.decode(T.self, from: data)
                return decoded
            } catch {
                let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                AppLogger.api.error("🔴 DECODE ERROR \(method) \(endpoint) | \(error) | raw: \(preview)")
                throw error
            }
        } catch let error where !(error is DecodingError) {
            let duration = CFAbsoluteTimeGetCurrent() - start
            if !(error is APIError) {
                AppLogger.logError(method, endpoint: endpoint, error: error, duration: duration)
            }
            throw error
        }
    }

    func requestRaw(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> APIResponse<EmptyData> {
        return try await request(endpoint, method: method, body: body, queryItems: queryItems)
    }

    func requestData(
        _ endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Data {
        let url = try buildURL(endpoint, queryItems: queryItems)
        var req = URLRequest(url: url)
        req.httpMethod = method
        injectAuth(&req)
        let (data, response) = try await session.data(for: req)
        try validateResponse(response, data: data)
        return data
    }

    // MARK: - File Download

    func download(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> (URL, String?) {
        let url = try buildURL(endpoint, queryItems: queryItems)
        var req = URLRequest(url: url)
        injectAuth(&req)

        AppLogger.api.info("📥 DOWNLOAD START \(endpoint)")

        let (tempURL, response) = try await session.download(for: req)

        guard let httpResp = response as? HTTPURLResponse else {
            throw APIError.serverError("非 HTTP 响应")
        }

        if httpResp.statusCode == 401 {
            AppLogger.api.error("📥 DOWNLOAD 401 Unauthorized \(endpoint)")
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResp.statusCode) else {
            AppLogger.api.error("📥 DOWNLOAD FAILED \(endpoint) → \(httpResp.statusCode)")
            throw APIError.httpError(httpResp.statusCode, "下载失败")
        }

        let suggestedName = httpResp.suggestedFilename

        let downloads = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let filename = suggestedName ?? UUID().uuidString
        let dest = downloads.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
        AppLogger.logDownload(endpoint, status: httpResp.statusCode, filename: suggestedName, size: fileSize)

        return (dest, suggestedName)
    }

    // MARK: - File Upload (multipart)

    func upload<T: Decodable>(
        _ endpoint: String,
        fileData: Data,
        fieldName: String,
        fileName: String,
        mimeType: String = "application/octet-stream",
        extraFields: [String: String]? = nil
    ) async throws -> T {
        let url = try buildURL(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        injectAuth(&req)

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        if let fields = extraFields {
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        AppLogger.logUpload(endpoint, fileName: fileName, size: fileData.count)

        let start = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(for: req)
        let duration = CFAbsoluteTimeGetCurrent() - start

        if let httpResp = response as? HTTPURLResponse {
            AppLogger.logResponse("UPLOAD", endpoint: endpoint, status: httpResp.statusCode, data: data, duration: duration)
        }

        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Helpers

    private func buildURL(_ endpoint: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        let urlString = baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/api" + endpoint
        guard var components = URLComponents(string: urlString) else {
            AppLogger.api.error("🔴 Invalid URL: \(urlString)")
            throw APIError.invalidURL
        }
        if let items = queryItems, !items.isEmpty {
            components.queryItems = (components.queryItems ?? []) + items
        }
        guard let url = components.url else {
            AppLogger.api.error("🔴 Cannot build URL from components: \(urlString)")
            throw APIError.invalidURL
        }
        return url
    }

    private func injectAuth(_ request: inout URLRequest) {
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResp = response as? HTTPURLResponse else {
            throw APIError.serverError("非 HTTP 响应")
        }
        switch httpResp.statusCode {
        case 200...299:
            return
        case 401:
            AppLogger.auth.error("🚫 401 Unauthorized — token may be expired")
            token = nil
            Task { @MainActor in
                NotificationCenter.default.post(name: APIClient.unauthorizedNotification, object: nil)
            }
            throw APIError.unauthorized
        case 409:
            let msg = (try? decoder.decode(APIResponse<EmptyData>.self, from: data))?.message ?? "冲突"
            throw APIError.conflict(msg, data)
        default:
            let msg = (try? decoder.decode(APIResponse<EmptyData>.self, from: data))?.message
                ?? "服务器错误 (\(httpResp.statusCode))"
            throw APIError.httpError(httpResp.statusCode, msg)
        }
    }

    // MARK: - Auth helpers

    func logout() {
        token = nil
        AppLogger.auth.info("👋 Logged out")
    }

    func downloadURL(_ endpoint: String) -> URL? {
        let urlString = baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/api" + endpoint
        guard var comps = URLComponents(string: urlString) else { return nil }
        if let t = token {
            comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "token", value: t)]
        }
        return comps.url
    }
}
