import Foundation

enum AppConstants {
    static let serverURL: String = {
        if let url = Bundle.main.infoDictionary?["ServerURL"] as? String, !url.isEmpty, !url.contains("$(") {
            return url
        }
        fatalError("ServerURL not configured in Info.plist — check Secrets.xcconfig")
    }()

    static let keychainServiceName = "com.certmanager.app"
    static let tokenKey = "auth_token"
    static let usernameKey = "last_username"
}
