import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var username = ""
    @Published var email = ""
    @Published var role = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var codeCooldown = 0
    @Published var isSendingCode = false

    private let authService = AuthService()
    private var cooldownTimer: Timer?
    private var unauthorizedObserver: Any?

    init() {
        self.isLoggedIn = APIClient.shared.isLoggedIn
        if let saved = UserDefaults.standard.string(forKey: AppConstants.usernameKey) {
            self.username = saved
        }
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: APIClient.unauthorizedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isLoggedIn else { return }
                AppLogger.auth.info("🚫 Received 401 — auto logout")
                self.isLoggedIn = false
                self.username = ""
                self.role = ""
            }
        }
        AppLogger.auth.info("🏁 AuthVM init | loggedIn=\(self.isLoggedIn) | user=\(self.username)")
    }

    deinit {
        if let observer = unauthorizedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func login(username: String, password: String) async {
        AppLogger.auth.info("🔐 Login attempt | user=\(username)")
        isLoading = true
        errorMessage = nil
        do {
            let result = try await authService.login(username: username, password: password)
            self.username = result.username
            self.email = result.email ?? ""
            self.role = result.role
            self.isLoggedIn = true
            UserDefaults.standard.set(result.username, forKey: AppConstants.usernameKey)
            AppLogger.auth.info("✅ Login success | user=\(result.username) | role=\(result.role)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.auth.error("❌ Login failed | \(error.localizedDescription)")
        }
        isLoading = false
    }

    func sendCode(email: String, type: String = "register") async {
        isSendingCode = true
        errorMessage = nil
        do {
            try await authService.sendCode(email: email, type: type)
            startCooldown()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingCode = false
    }

    func register(username: String, email: String, code: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await authService.register(
                username: username, email: email, code: code, password: password
            )
            self.username = result.username
            self.email = result.email
            self.role = result.role
            self.isLoggedIn = true
            UserDefaults.standard.set(result.username, forKey: AppConstants.usernameKey)
            AppLogger.auth.info("✅ Register success | user=\(result.username)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.auth.error("❌ Register failed | \(error.localizedDescription)")
        }
        isLoading = false
    }

    func logout() async {
        AppLogger.auth.info("👋 Logout | user=\(self.username)")
        await NotificationManager.shared.clearToken()
        await authService.logout()
        isLoggedIn = false
        username = ""
        email = ""
        role = ""
    }

    func checkAuth() async {
        AppLogger.auth.info("🔍 Checking auth state...")
        guard APIClient.shared.isLoggedIn else {
            AppLogger.auth.info("🔍 No token found — not logged in")
            isLoggedIn = false
            return
        }
        do {
            let user = try await authService.me()
            username = user.username
            email = user.email ?? ""
            role = user.role
            isLoggedIn = true
            AppLogger.auth.info("✅ Auth valid | user=\(user.username) | role=\(user.role)")
        } catch {
            isLoggedIn = false
            APIClient.shared.logout()
            AppLogger.auth.error("❌ Auth check failed — logging out | \(error.localizedDescription)")
        }
    }

    func changePassword(old: String, new: String) async throws {
        AppLogger.auth.info("🔑 Changing password...")
        try await authService.changePassword(old: old, new: new)
        AppLogger.auth.info("✅ Password changed")
    }

    private func startCooldown() {
        codeCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.codeCooldown -= 1
                if self.codeCooldown <= 0 { timer.invalidate() }
            }
        }
    }
}
