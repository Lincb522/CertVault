import SwiftUI
import HiconIcons
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var appearance: AppearanceManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @StateObject private var updateService = UpdateService.shared
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var showClearCacheConfirm = false
    @State private var showSMTP = false
    @State private var showUpdateSheet = false
    @State private var showAlreadyLatest = false
    @State private var showUpdateError: String?
    @State private var serverStatus: ServerStatus = .checking
    @State private var cacheSize: Int64 = 0
    @State private var cacheCleared = false

    private enum ServerStatus {
        case checking, online(String), offline
    }

    private var roleDisplayName: String {
        switch authVM.role {
        case "superadmin": return NSLocalizedString("user.role.superadmin", comment: "")
        case "admin": return NSLocalizedString("user.role.admin", comment: "")
        default: return NSLocalizedString("user.role.user", comment: "")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileCard
                if authVM.role == "superadmin" {
                    adminSection
                }
                appearanceSection
                securitySection
                cacheSection
                notificationSection
                aboutSection
                logoutSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle(L10n.Settings.title)
        .alert(L10n.Settings.logoutTitle, isPresented: $showLogoutConfirm) {
            Button(L10n.Settings.logout, role: .destructive) {
                Task { await authVM.logout() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.logoutMessage)
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet()
        }
        .alert(L10n.Settings.clearCacheTitle, isPresented: $showClearCacheConfirm) {
            Button(L10n.Settings.clearCache, role: .destructive) { clearCache() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.clearCacheMessage)
        }
        .alert(L10n.Settings.clearCacheDone, isPresented: $cacheCleared) {
            Button(L10n.ok) {}
        }
        .task { await checkServerHealth() }
        .task { await updateService.checkForUpdate() }
        .onAppear { cacheSize = DatabaseManager.shared.cacheSize() }
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.dsAccentBlue, .dsAccentPurple],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 50, height: 50)
                Text(String(authVM.username.prefix(1)).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(authVM.username)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(roleDisplayName)
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }

            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Admin

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(NSLocalizedString("settings.admin", comment: ""))

            NavigationLink {
                UserManagementView()
            } label: {
                HStack(spacing: 12) {
                    HIcon(AppIcon.group)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentPurple)
                        .frame(width: 20)
                    Text(L10n.Settings.userManagement)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    HIcon(AppIcon.chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dsMuted.opacity(0.4))
                }
                .padding(14)
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
            }

            Button { showSMTP = true } label: {
                HStack(spacing: 12) {
                    HIcon(AppIcon.email)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentBlue)
                        .frame(width: 20)
                    Text(L10n.Settings.emailConfig)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    HIcon(AppIcon.chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dsMuted.opacity(0.4))
                }
                .padding(14)
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
            }
            .sheet(isPresented: $showSMTP) {
                SMTPConfigSheet()
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(NSLocalizedString("settings.appearance", comment: ""))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(appearance.mode == .dark ? AppIcon.moon : appearance.mode == .light ? AppIcon.sun : AppIcon.settings)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentPurple)
                        .frame(width: 20)
                    Text(L10n.Settings.displayMode)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Picker("", selection: $appearance.mode) {
                    ForEach(AppearanceManager.Mode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(NSLocalizedString("settings.security", comment: ""))

            Button { showChangePassword = true } label: {
                HStack(spacing: 12) {
                    HIcon(AppIcon.lock)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentOrange)
                        .frame(width: 20)
                    Text(L10n.Settings.changePassword)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    HIcon(AppIcon.chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dsMuted.opacity(0.4))
                }
                .padding(14)
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Cache

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.Settings.cache)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(AppIcon.category)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentCyan)
                        .frame(width: 20)
                    Text(L10n.Settings.cache)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    Text(formattedCacheSize)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.dsMuted)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                Button {
                    showClearCacheConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        HIcon(AppIcon.delete)
                            .font(.body)
                            .foregroundStyle(Color.dsAccentPink)
                            .frame(width: 20)
                        Text(L10n.Settings.clearCache)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsAccentPink)
                        Spacer()
                        HIcon(AppIcon.chevronRight)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.dsMuted.opacity(0.4))
                    }
                    .padding(14)
                }
            }
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
    }

    private var formattedCacheSize: String {
        if cacheSize < 1024 {
            return "\(cacheSize) B"
        } else if cacheSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(cacheSize) / 1024)
        } else {
            return String(format: "%.1f MB", Double(cacheSize) / 1024 / 1024)
        }
    }

    private func clearCache() {
        do {
            try DatabaseManager.shared.clearAll()
            cacheSize = DatabaseManager.shared.cacheSize()
            cacheCleared = true
        } catch {
            AppLogger.data.error("Clear cache failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.Settings.notification)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(AppIcon.pushKey)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentBlue)
                        .frame(width: 20)
                    Text(L10n.Settings.notification)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    notificationStatusBadge
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                if notificationManager.authorizationStatus == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            HIcon(AppIcon.settings)
                                .font(.body)
                                .foregroundStyle(Color.dsAccentOrange)
                                .frame(width: 20)
                            Text(NSLocalizedString("settings.notification.goSettings", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccentOrange)
                            Spacer()
                            HIcon(AppIcon.chevronRight)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.dsMuted.opacity(0.4))
                        }
                        .padding(14)
                    }
                } else if notificationManager.authorizationStatus == .notDetermined {
                    Button {
                        Task { await notificationManager.requestPermission() }
                    } label: {
                        HStack(spacing: 12) {
                            HIcon(AppIcon.pushKey)
                                .font(.body)
                                .foregroundStyle(Color.dsAccent)
                                .frame(width: 20)
                            Text(NSLocalizedString("settings.notification.enable", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccent)
                            Spacer()
                            HIcon(AppIcon.chevronRight)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.dsMuted.opacity(0.4))
                        }
                        .padding(14)
                    }
                } else {
                    HStack(spacing: 12) {
                        HIcon(AppIcon.tick)
                            .font(.body)
                            .foregroundStyle(Color.dsAccent)
                            .frame(width: 20)
                        Text("Device Token")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsText)
                        Spacer()
                        if let token = notificationManager.deviceToken {
                            Text(token.prefix(12) + "...")
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.dsMuted)
                        } else {
                            Text(NSLocalizedString("settings.notification.waiting", comment: ""))
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    .padding(14)
                }
            }
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var notificationStatusBadge: some View {
        switch notificationManager.authorizationStatus {
        case .authorized:
            HStack(spacing: 6) {
                Circle().fill(Color.dsAccent).frame(width: 8, height: 8)
                Text(NSLocalizedString("settings.notification.enabled", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(Color.dsAccent)
            }
        case .denied:
            HStack(spacing: 6) {
                Circle().fill(Color.dsAccentPink).frame(width: 8, height: 8)
                Text(NSLocalizedString("settings.notification.denied", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(Color.dsAccentPink)
            }
        case .provisional:
            HStack(spacing: 6) {
                Circle().fill(Color.dsAccentOrange).frame(width: 8, height: 8)
                Text(NSLocalizedString("settings.notification.provisional", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(Color.dsAccentOrange)
            }
        default:
            HStack(spacing: 6) {
                Circle().fill(Color.dsMuted).frame(width: 8, height: 8)
                Text(NSLocalizedString("settings.notification.notDetermined", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(NSLocalizedString("settings.about", comment: ""))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(AppIcon.server)
                        .font(.body)
                        .foregroundStyle(Color.dsAccent)
                        .frame(width: 20)
                    Text(L10n.Settings.serverStatus)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    switch serverStatus {
                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                    case .online(_):
                        HStack(spacing: 6) {
                            Circle().fill(Color.dsAccent).frame(width: 8, height: 8)
                            Text(Localized.status("ONLINE"))
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccent)
                        }
                    case .offline:
                        HStack(spacing: 6) {
                            Circle().fill(Color.dsAccentPink).frame(width: 8, height: 8)
                            Text(Localized.status("OFFLINE"))
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccentPink)
                        }
                    }
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                HStack(spacing: 12) {
                    HIcon(AppIcon.info)
                        .font(.body)
                        .foregroundStyle(Color.dsMuted)
                        .frame(width: 20)
                    Text(L10n.Settings.version)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    Text(appVersion)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.dsMuted)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                Button {
                    Task {
                        await updateService.checkForUpdate()
                        if updateService.updateAvailable {
                            showUpdateSheet = true
                        } else if let err = updateService.lastError {
                            showUpdateError = err
                        } else {
                            showAlreadyLatest = true
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        HIcon(AppIcon.refresh)
                            .font(.body)
                            .foregroundStyle(Color.dsAccentBlue)
                            .frame(width: 20)
                        Text(NSLocalizedString("settings.checkUpdate", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(Color.dsText)
                        Spacer()
                        if updateService.isChecking {
                            ProgressView().controlSize(.small)
                        } else if updateService.updateAvailable {
                            HStack(spacing: 4) {
                                Circle().fill(Color.dsAccentPink).frame(width: 8, height: 8)
                                Text(NSLocalizedString("settings.updateAvailable", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(Color.dsAccentPink)
                            }
                        } else {
                            HIcon(AppIcon.chevronRight)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.dsMuted.opacity(0.4))
                        }
                    }
                    .padding(14)
                }
            }
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showUpdateSheet) {
            UpdateSheet()
                .environmentObject(updateService)
        }
        .alert("已是最新版本", isPresented: $showAlreadyLatest) {
            Button("好的") {}
        } message: {
            Text("当前版本 v\(updateService.currentVersion) 已是最新")
        }
        .alert("检查更新失败", isPresented: .init(
            get: { showUpdateError != nil },
            set: { if !$0 { showUpdateError = nil } }
        )) {
            Button("好的") { showUpdateError = nil }
        } message: {
            Text(showUpdateError ?? "")
        }
    }

    // MARK: - Logout

    private func checkServerHealth() async {
        struct HealthResp: Decodable {
            let status: String
            let time: String
        }
        guard let url = URL(string: "\(AppConstants.serverURL.trimmingCharacters(in: .init(charactersIn: "/")))/api/health") else {
            serverStatus = .offline
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(HealthResp.self, from: data)
            serverStatus = .online(resp.time)
        } catch {
            serverStatus = .offline
        }
    }

    private var logoutSection: some View {
        Button(role: .destructive) { showLogoutConfirm = true } label: {
            HStack(spacing: 8) {
                HIcon(AppIcon.logout).font(.body)
                Text(L10n.Settings.logout)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color.dsAccentPink)
            .background(Color.dsAccentPink.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsAccentPink.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Change Password

private struct ChangePasswordSheet: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(NSLocalizedString("settings.changePassword.current", comment: ""), text: $oldPassword)
                    SecureField(NSLocalizedString("settings.changePassword.new", comment: ""), text: $newPassword)
                    SecureField(NSLocalizedString("settings.changePassword.confirm", comment: ""), text: $confirmPassword)
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.Settings.changePassword)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.confirm) { save() }
                        .disabled(!isValid || isLoading)
                }
            }
            .alert(NSLocalizedString("settings.changePassword.success", comment: ""), isPresented: $success) {
                Button(L10n.ok) { dismiss() }
            } message: {
                Text(NSLocalizedString("settings.changePassword.successMsg", comment: ""))
            }
        }
        .presentationDetents([.medium])
    }

    private var isValid: Bool {
        !oldPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func save() {
        guard newPassword == confirmPassword else {
            errorMsg = L10n.Register.passwordMismatch
            return
        }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await authVM.changePassword(old: oldPassword, new: newPassword)
                success = true
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - SMTP Config

private struct SMTPConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config: SMTPConfig?
    @State private var isLoading = true
    @State private var errorMsg: String?

    private let authService = AuthService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(L10n.loading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMsg {
                    VStack(spacing: 12) {
                        HIcon(AppIcon.warning)
                            .font(.largeTitle)
                            .foregroundStyle(Color.dsAccentOrange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let smtp = config {
                    List {
                        Section(NSLocalizedString("settings.email.connection", comment: "")) {
                            row(NSLocalizedString("settings.email.smtpHost", comment: ""), smtp.host.isEmpty ? Localized.status("NOTCONFIGURED") : smtp.host)
                            row(NSLocalizedString("settings.email.port", comment: ""), smtp.port)
                            row(NSLocalizedString("settings.email.ssl", comment: ""), smtp.secure == "true" ? Localized.status("SSLENABLED") : Localized.status("SSLDISABLED"))
                        }
                        Section(L10n.account) {
                            row(NSLocalizedString("settings.email.sender", comment: ""), smtp.user.isEmpty ? Localized.status("NOTCONFIGURED") : smtp.user)
                        }
                        Section(NSLocalizedString("settings.email.status", comment: "")) {
                            HStack {
                                Text(L10n.Settings.emailConfig)
                                    .foregroundStyle(Color.dsText)
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(smtp.configured ? Color.dsAccent : Color.dsAccentPink)
                                        .frame(width: 8, height: 8)
                                    Text(smtp.configured ? Localized.status("CONFIGURED") : Localized.status("NOTCONFIGURED"))
                                        .foregroundStyle(smtp.configured ? Color.dsAccent : Color.dsAccentPink)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Settings.emailConfig)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .task { await load() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.dsText)
            Spacer()
            Text(value)
                .foregroundStyle(Color.dsMuted)
                .font(.subheadline.monospaced())
        }
    }

    private func load() async {
        do {
            config = try await authService.smtpConfig()
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
