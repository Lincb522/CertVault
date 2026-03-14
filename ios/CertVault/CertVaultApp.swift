import SwiftUI
import UserNotifications

@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    enum Mode: Int, CaseIterable {
        case system = 0
        case light = 1
        case dark = 2

        var label: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "日间"
            case .dark: return "夜间"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    @Published var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "app_appearance_mode") }
    }

    private init() {
        let raw = UserDefaults.standard.integer(forKey: "app_appearance_mode")
        self.mode = Mode(rawValue: raw) ?? .system
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            NotificationManager.shared.didRegister(tokenData: deviceToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            NotificationManager.shared.didFailToRegister(error: error)
        }
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            NotificationManager.shared.handleNotification(userInfo, completionHandler: completionHandler)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            NotificationManager.shared.handleNotification(userInfo)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let switchTab = Notification.Name("CertVault.switchTab")
}

// MARK: - App

@main
struct CertVaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var appearance = AppearanceManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    init() {
        AppLogger.ui.info("🚀 CertVaultApp launched | iOS \(UIDevice.current.systemVersion) | \(UIDevice.current.model)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(appearance)
                .environmentObject(notificationManager)
                .preferredColorScheme(appearance.mode.colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    await notificationManager.calibrateTime()
                    await notificationManager.refreshStatus()
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "certvault" else { return }
        switch url.host {
        case "dashboard":
            NotificationCenter.default.post(name: .switchTab, object: 0)
        case "accounts":
            NotificationCenter.default.post(name: .switchTab, object: 1)
        case "devices":
            NotificationCenter.default.post(name: .switchTab, object: 2)
        case "certificates":
            NotificationCenter.default.post(name: .switchTab, object: 3)
        default:
            break
        }
    }
}
