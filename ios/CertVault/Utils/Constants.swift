import Foundation

enum AppConstants {
    static let serverURL: String = {
        if let url = Bundle.main.infoDictionary?["ServerURL"] as? String, !url.isEmpty, !url.contains("$(") {
            return url
        }
        return "https:///p12.zijiu522.cn"
    }()

    static let keychainServiceName = "com.certmanager.app"
    static let tokenKey = "auth_token"
    static let usernameKey = "last_username"
    static let appGroupID = "group.com.certvault.app"
}
