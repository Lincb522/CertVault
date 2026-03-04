import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var deviceToken: String?
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let pushService = PushService()
    private let tokenKey = "apns_device_token"

    override private init() {
        super.init()
        if let saved = UserDefaults.standard.string(forKey: tokenKey) {
            deviceToken = saved
        }
    }

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            AppLogger.data.info("🔔 Push permission \(granted ? "granted" : "denied")")
            await refreshStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            AppLogger.data.error("🔔 Push permission error: \(error.localizedDescription)")
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func didRegister(tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        AppLogger.data.info("🔔 APNs token: \(token.prefix(16))...")

        Task { await uploadToken(token) }
    }

    func didFailToRegister(error: Error) {
        AppLogger.data.error("🔔 APNs registration failed: \(error.localizedDescription)")
    }

    func handleNotification(_ userInfo: [AnyHashable: Any], completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        AppLogger.data.info("🔔 Push received: \(userInfo.keys)")

        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any] {
            let title = alert["title"] as? String ?? ""
            let body = alert["body"] as? String ?? ""
            AppLogger.data.info("🔔 Push content: \(title) - \(body)")
        }

        if let type = userInfo["type"] as? String {
            handlePushAction(type: type, data: userInfo)
        }

        completionHandler?(.newData)
    }

    func clearToken() {
        if let token = deviceToken {
            Task { await removeToken(token) }
        }
        deviceToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    // MARK: - Token Upload

    private func uploadToken(_ token: String) async {
        do {
            try await pushService.registerDevice(token: token, platform: "ios")
            AppLogger.data.info("🔔 Token uploaded to server")
        } catch {
            AppLogger.data.error("🔔 Token upload failed: \(error.localizedDescription)")
        }
    }

    private func removeToken(_ token: String) async {
        do {
            try await pushService.unregisterDevice(token: token)
            AppLogger.data.info("🔔 Token removed from server")
        } catch {
            AppLogger.data.error("🔔 Token removal failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Push Actions

    private func handlePushAction(type: String, data: [AnyHashable: Any]) {
        switch type {
        case "cert_expiring":
            AppLogger.data.info("🔔 Certificate expiration warning")
        case "task_complete":
            AppLogger.data.info("🔔 Task completed")
        case "profile_expiring":
            AppLogger.data.info("🔔 Profile expiration warning")
        default:
            break
        }
    }
}
