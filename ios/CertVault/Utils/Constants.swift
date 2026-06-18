import Foundation

enum AppConstants {
    static let serverURL: String = {
        if let url = Bundle.main.infoDictionary?["ServerURL"] as? String, !url.isEmpty, !url.contains("$(") {
            return url
        }
        return "http://127.0.0.1:3006"
    }()

    static let keychainServiceName = "com.example.certvault"
    static let tokenKey = "auth_token"
    static let usernameKey = "last_username"
    static let appGroupID = "group.com.example.certvault"
}
