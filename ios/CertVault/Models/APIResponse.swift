import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
}

struct EmptyData: Decodable {}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case conflict(String, Data?)
    case networkError(Error)
    case decodingError(Error)
    case noData
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .unauthorized: return "未登录或登录已过期"
        case .serverError(let msg): return msg
        case .conflict(let msg, _): return msg
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        case .decodingError(let err): return "数据解析错误: \(err.localizedDescription)"
        case .noData: return "服务器未返回数据"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        }
    }
}
