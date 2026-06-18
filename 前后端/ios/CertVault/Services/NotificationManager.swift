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
    private let lastUploadKey = "apns_last_upload_time"
    private let uploadInterval: TimeInterval = 30 * 60
    private var serverTimeOffset: TimeInterval = 0

    override private init() {
        super.init()
        if let saved = UserDefaults.standard.string(forKey: tokenKey) {
            deviceToken = saved
        }
    }

    private var calibratedNow: Date {
        Date().addingTimeInterval(serverTimeOffset)
    }

    func calibrateTime() async {
        guard let url = URL(string: APIClient.shared.baseURL + "/push/status") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        do {
            let localBefore = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let localAfter = Date()
            let localMid = localBefore.addingTimeInterval(localAfter.timeIntervalSince(localBefore) / 2)

            if let httpResp = response as? HTTPURLResponse,
               let dateStr = httpResp.value(forHTTPHeaderField: "Date") {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                if let serverDate = df.date(from: dateStr) {
                    serverTimeOffset = serverDate.timeIntervalSince(localMid)
                    if abs(serverTimeOffset) > 2 {
                        AppLogger.data.info("🔔 Time calibration: offset \(String(format: "%.1f", self.serverTimeOffset))s")
                    }
                }
            }
        } catch {
            AppLogger.data.warning("🔔 Time calibration failed, using local time")
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
        let previousToken = deviceToken
        deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        AppLogger.data.info("🔔 APNs token: \(token.prefix(16))...")

        let tokenChanged = token != previousToken
        let lastUpload = UserDefaults.standard.double(forKey: lastUploadKey)
        let elapsed = calibratedNow.timeIntervalSince1970 - lastUpload

        if tokenChanged || elapsed > uploadInterval {
            Task { await uploadToken(token) }
        } else {
            AppLogger.data.info("🔔 Token unchanged, skip upload (last: \(Int(elapsed))s ago)")
        }
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
        let device = UIDevice.current
        let deviceName = device.name
        let model = DeviceInfo.modelName
        let systemVersion = device.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let fullAppVersion = "\(appVersion)(\(buildNumber))"

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let reportTime = fmt.string(from: calibratedNow)

        let label = "\(deviceName) · \(model) · iOS \(systemVersion) · v\(fullAppVersion)"

        #if DEBUG
        let isSandbox = true
        #else
        let isSandbox = false
        #endif

        do {
            try await pushService.registerDevice(
                token: token,
                platform: "ios",
                sandbox: isSandbox,
                label: label,
                deviceName: deviceName,
                model: model,
                osVersion: "iOS \(systemVersion)",
                appVersion: fullAppVersion,
                reportedAt: reportTime
            )
            UserDefaults.standard.set(calibratedNow.timeIntervalSince1970, forKey: lastUploadKey)
            AppLogger.data.info("🔔 Token uploaded to server (model: \(model), sandbox: \(isSandbox))")
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
