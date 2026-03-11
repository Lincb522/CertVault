import Foundation

struct CertCheckService {
    private let api = APIClient.shared

    func validate(fileData: Data, fileName: String, password: String?, accountId: String?) async throws -> CertCheckResponse {
        var extraFields: [String: String] = [:]
        if let pw = password, !pw.isEmpty {
            extraFields["password"] = pw
        }
        if let accId = accountId, !accId.isEmpty {
            extraFields["account_id"] = accId
        }

        let mimeType: String
        if fileName.hasSuffix(".zip") {
            mimeType = "application/zip"
        } else if fileName.hasSuffix(".p12") || fileName.hasSuffix(".pfx") {
            mimeType = "application/x-pkcs12"
        } else if fileName.hasSuffix(".mobileprovision") {
            mimeType = "application/octet-stream"
        } else {
            mimeType = "application/octet-stream"
        }

        let resp: APIResponse<CertCheckResponse> = try await api.upload(
            "/cert-check/validate",
            fileData: fileData,
            fieldName: "files",
            fileName: fileName,
            mimeType: mimeType,
            extraFields: extraFields.isEmpty ? nil : extraFields
        )
        guard let data = resp.data else {
            throw APIError.serverError(resp.message ?? "验证失败")
        }
        return data
    }
}
