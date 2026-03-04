import Foundation

struct LoginResponse: Decodable {
    let token: String
    let username: String
    let email: String?
    let role: String
    let expires_at: String?
}

struct RegisterResponse: Decodable {
    let token: String
    let username: String
    let email: String
    let role: String
    let expires_at: String?
}

struct UserInfo: Decodable {
    let username: String
    let email: String?
    let email_verified: Int?
    let role: String
}

struct AuthService {
    private let api = APIClient.shared

    func login(username: String, password: String) async throws -> LoginResponse {
        struct Body: Encodable {
            let username: String
            let password: String
        }
        let resp: APIResponse<LoginResponse> = try await api.request(
            "/auth/login", method: "POST",
            body: Body(username: username, password: password)
        )
        guard let data = resp.data else {
            throw APIError.serverError(resp.message ?? "登录失败")
        }
        api.token = data.token
        return data
    }

    func sendCode(email: String, type: String = "register") async throws {
        struct Body: Encodable {
            let email: String
            let type: String
        }
        let resp = try await api.requestRaw(
            "/auth/send-code", method: "POST",
            body: Body(email: email, type: type)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "发送验证码失败") }
    }

    func register(username: String, email: String, code: String, password: String) async throws -> RegisterResponse {
        struct Body: Encodable {
            let username: String
            let email: String
            let code: String
            let password: String
        }
        let resp: APIResponse<RegisterResponse> = try await api.request(
            "/auth/register", method: "POST",
            body: Body(username: username, email: email, code: code, password: password)
        )
        guard let data = resp.data else {
            throw APIError.serverError(resp.message ?? "注册失败")
        }
        api.token = data.token
        return data
    }

    func logout() async {
        _ = try? await api.requestRaw("/auth/logout", method: "POST")
        api.logout()
    }

    func me() async throws -> UserInfo {
        let resp: APIResponse<UserInfo> = try await api.request("/auth/me")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }

    func changePassword(old: String, new: String) async throws {
        struct Body: Encodable {
            let old_password: String
            let new_password: String
        }
        let resp = try await api.requestRaw(
            "/auth/change-password", method: "POST",
            body: Body(old_password: old, new_password: new)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "修改密码失败") }
    }

    // MARK: - Admin

    func listUsers() async throws -> [ManagedUser] {
        let resp: APIResponse<[ManagedUser]> = try await api.request("/auth/users")
        return resp.data ?? []
    }

    func updateUserRole(id: String, role: String) async throws {
        struct Body: Encodable { let role: String }
        let resp = try await api.requestRaw(
            "/auth/users/\(id)/role", method: "PUT",
            body: Body(role: role)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "更新角色失败") }
    }

    func deleteUser(id: String) async throws {
        let resp = try await api.requestRaw("/auth/users/\(id)", method: "DELETE")
        if !resp.success { throw APIError.serverError(resp.message ?? "删除失败") }
    }

    func resetUserPassword(id: String, newPassword: String) async throws {
        struct Body: Encodable { let new_password: String }
        let resp = try await api.requestRaw(
            "/auth/users/\(id)/reset-password", method: "POST",
            body: Body(new_password: newPassword)
        )
        if !resp.success { throw APIError.serverError(resp.message ?? "重置密码失败") }
    }

    // MARK: - SMTP

    func smtpConfig() async throws -> SMTPConfig {
        let resp: APIResponse<SMTPConfig> = try await api.request("/auth/smtp-config")
        guard let data = resp.data else { throw APIError.noData }
        return data
    }
}

struct SMTPConfig: Decodable {
    let host: String
    let port: String
    let secure: String
    let user: String
    let configured: Bool
}

struct ManagedUser: Decodable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let role: String
    let created_at: String?
}
