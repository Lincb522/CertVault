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
            VStack(spacing: DS.spacingXL) {
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
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacingXL)
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
        DSGroupedCard {
            HStack(spacing: DS.spacingMD) {
                ZStack {
                    Circle()
                        .fill(Color.dsBrandGradient)
                        .frame(width: 50, height: 50)
                    Text(String(authVM.username.prefix(1)).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(authVM.username)
                        .font(.headline)
                        .foregroundStyle(Color.dsText)
                    Text(roleDisplayName)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }

                Spacer()
            }
            .padding(DS.spacingLG)
        }
    }

    // MARK: - Admin

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("settings.admin", comment: ""))
            DSGroupedCard {
                NavigationLink { UserManagementView() } label: {
                    DSRow(icon: AppIcon.group, iconColor: .dsPurple, title: L10n.Settings.userManagement, useGradientIcon: true)
                }
                .buttonStyle(.plain)
                DSDivider()
                Button { showSMTP = true } label: {
                    DSRow(icon: AppIcon.email, iconColor: .dsBlue, title: L10n.Settings.emailConfig, useGradientIcon: true)
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showSMTP) {
                SMTPConfigSheet()
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("settings.appearance", comment: ""))
            DSGroupedCard {
                HStack(spacing: DS.spacingMD) {
                    HIcon(appearance.mode == .dark ? AppIcon.moon : appearance.mode == .light ? AppIcon.sun : AppIcon.settings)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.dsPurple.gradient, in: RoundedRectangle(cornerRadius: DS.radiusSM + 2))
                    Text(L10n.Settings.displayMode)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
                    Spacer()
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.top, DS.spacingLG)
                .padding(.bottom, DS.spacingSM)

                Picker("", selection: $appearance.mode) {
                    ForEach(AppearanceManager.Mode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.spacingLG)
                .padding(.bottom, DS.spacingLG)
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("settings.security", comment: ""))
            DSGroupedCard {
                Button { showChangePassword = true } label: {
                    DSRow(icon: AppIcon.lock, iconColor: .dsOrange, title: L10n.Settings.changePassword, useGradientIcon: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Cache

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Settings.cache)
            DSGroupedCard {
                DSRow(icon: AppIcon.category, iconColor: .dsCyan, title: L10n.Settings.cache, trailing: AnyView(
                    Text(formattedCacheSize)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.dsTextSecondary)
                ), showChevron: false, useGradientIcon: true)
                DSDivider()
                Button { showClearCacheConfirm = true } label: {
                    DSRow(icon: AppIcon.delete, iconColor: .dsPink, title: L10n.Settings.clearCache, useGradientIcon: true)
                }
                .buttonStyle(.plain)
            }
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
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Settings.notification)
            DSGroupedCard {
                DSRow(icon: AppIcon.pushKey, iconColor: .dsBlue, title: L10n.Settings.notification, trailing: AnyView(notificationStatusBadge), showChevron: false, useGradientIcon: true)
                DSDivider()

                if notificationManager.authorizationStatus == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        DSRow(icon: AppIcon.settings, iconColor: .dsOrange, title: NSLocalizedString("settings.notification.goSettings", comment: ""), useGradientIcon: true)
                    }
                    .buttonStyle(.plain)
                } else if notificationManager.authorizationStatus == .notDetermined {
                    Button {
                        Task { await notificationManager.requestPermission() }
                    } label: {
                        DSRow(icon: AppIcon.pushKey, iconColor: .dsGreen, title: NSLocalizedString("settings.notification.enable", comment: ""), useGradientIcon: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    DSRow(icon: AppIcon.tick, iconColor: .dsGreen, title: "Device Token", trailing: AnyView(
                        Group {
                            if let token = notificationManager.deviceToken {
                                Text(token.prefix(12) + "...")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(Color.dsTextSecondary)
                            } else {
                                Text(NSLocalizedString("settings.notification.waiting", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(Color.dsTextSecondary)
                            }
                        }
                    ), showChevron: false, useGradientIcon: true)
                }
            }
        }
    }

    @ViewBuilder
    private var notificationStatusBadge: some View {
        switch notificationManager.authorizationStatus {
        case .authorized:
            DSBadge(text: NSLocalizedString("settings.notification.enabled", comment: ""), color: .dsGreen)
        case .denied:
            DSBadge(text: NSLocalizedString("settings.notification.denied", comment: ""), color: .dsPink)
        case .provisional:
            DSBadge(text: NSLocalizedString("settings.notification.provisional", comment: ""), color: .dsOrange)
        default:
            DSBadge(text: NSLocalizedString("settings.notification.notDetermined", comment: ""), color: .dsTextSecondary)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("settings.about", comment: ""))
            DSGroupedCard {
                DSRow(icon: AppIcon.server, iconColor: .dsGreen, title: L10n.Settings.serverStatus, trailing: AnyView(serverStatusTrailing), showChevron: false, useGradientIcon: true)
                DSDivider()
                DSRow(icon: AppIcon.info, iconColor: .dsTextSecondary, title: L10n.Settings.version, trailing: AnyView(
                    Text(appVersion)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.dsTextSecondary)
                ), showChevron: false, useGradientIcon: true)
                DSDivider()
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
                    DSRow(icon: AppIcon.refresh, iconColor: .dsBlue, title: NSLocalizedString("settings.checkUpdate", comment: ""), trailing: AnyView(updateStatusTrailing), useGradientIcon: true)
                }
                .buttonStyle(.plain)
            }
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

    @ViewBuilder
    private var serverStatusTrailing: some View {
        switch serverStatus {
        case .checking:
            ProgressView().controlSize(.small)
        case .online:
            DSBadge(text: Localized.status("ONLINE"), color: .dsGreen)
        case .offline:
            DSBadge(text: Localized.status("OFFLINE"), color: .dsDanger)
        }
    }

    @ViewBuilder
    private var updateStatusTrailing: some View {
        if updateService.isChecking {
            ProgressView().controlSize(.small)
        } else if updateService.updateAvailable {
            DSBadge(text: NSLocalizedString("settings.updateAvailable", comment: ""), color: .dsPink)
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
        DSDangerButton(L10n.Settings.logout, icon: AppIcon.logout) {
            showLogoutConfirm = true
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
                        Text(err).foregroundStyle(Color.dsDanger).font(.caption)
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
