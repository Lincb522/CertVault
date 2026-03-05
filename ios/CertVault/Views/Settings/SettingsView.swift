import SwiftUI
import HiconIcons
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var appearance: AppearanceManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var showClearCacheConfirm = false
    @State private var showSMTP = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountContactAdmin = false
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
            VStack(alignment: .leading, spacing: DS.spacingXL) {
                profileCard
                if authVM.role == "superadmin" {
                    adminSection
                }
                appearanceSection
                securitySection
                cacheSection
                notificationSection
                aboutSection
                deleteAccountSection
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
        .alert("删除账户", isPresented: $showDeleteAccountConfirm) {
            Button("删除", role: .destructive) { deleteAccount() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text("确定要删除账户吗？此操作不可恢复。")
        }
        .alert("请联系管理员删除账户", isPresented: $showDeleteAccountContactAdmin) {
            Button(L10n.ok) {}
        } message: {
            Text("请联系管理员删除账户")
        }
        .task { await checkServerHealth() }
        .onAppear { cacheSize = DatabaseManager.shared.cacheSize() }
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: DS.spacingMD) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.dsBlue, .dsPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
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
        .cardStyle()
    }

    // MARK: - Admin

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("settings.admin", comment: ""))

            DSGroupedCard {
                NavigationLink {
                    UserManagementView()
                } label: {
                    DSRow(icon: AppIcon.group, iconColor: .dsPurple, title: L10n.Settings.userManagement)
                }
                .buttonStyle(.dsPressed)

                DSDivider()

                Button { showSMTP = true } label: {
                    DSRow(icon: AppIcon.email, iconColor: .dsBlue, title: L10n.Settings.emailConfig)
                }
                .buttonStyle(.dsPressed)
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
                        .foregroundStyle(Color.dsPurple)
                        .frame(width: 32, height: 32)
                        .background(Color.dsPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                    Text(L10n.Settings.displayMode)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)

                    Spacer()
                }
                .padding(.vertical, DS.spacingMD)
                .padding(.horizontal, DS.spacingLG)

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
                    DSRow(icon: AppIcon.lock, iconColor: .dsOrange, title: L10n.Settings.changePassword)
                }
                .buttonStyle(.dsPressed)
            }
        }
    }

    // MARK: - Cache

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Settings.cache)

            DSGroupedCard {
                DSRow(
                    icon: AppIcon.category,
                    iconColor: .dsCyan,
                    title: L10n.Settings.cache,
                    trailing: AnyView(Text(formattedCacheSize).font(.subheadline.monospaced()).foregroundStyle(Color.dsTextSecondary)),
                    showChevron: false
                )

                DSDivider()

                Button { showClearCacheConfirm = true } label: {
                    DSRow(icon: AppIcon.delete, iconColor: .dsDanger, title: L10n.Settings.clearCache)
                }
                .buttonStyle(.dsPressed)
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
                HStack(spacing: DS.spacingMD) {
                    HIcon(AppIcon.pushKey)
                        .font(.callout)
                        .foregroundStyle(Color.dsBlue)
                        .frame(width: 32, height: 32)
                        .background(Color.dsBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                    Text(L10n.Settings.notification)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)

                    Spacer()

                    notificationStatusBadge
                }
                .padding(.vertical, DS.spacingMD)
                .padding(.horizontal, DS.spacingLG)
                .frame(minHeight: DS.minTouchTarget)
                .contentShape(Rectangle())

                if notificationManager.authorizationStatus == .denied {
                    DSDivider()

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        DSRow(icon: AppIcon.settings, iconColor: .dsOrange, title: NSLocalizedString("settings.notification.goSettings", comment: ""))
                    }
                    .buttonStyle(.dsPressed)
                } else if notificationManager.authorizationStatus == .notDetermined {
                    DSDivider()

                    Button {
                        Task { await notificationManager.requestPermission() }
                    } label: {
                        DSRow(icon: AppIcon.pushKey, iconColor: .dsGreen, title: NSLocalizedString("settings.notification.enable", comment: ""))
                    }
                    .buttonStyle(.dsPressed)
                } else {
                    DSDivider()

                    HStack(spacing: DS.spacingMD) {
                        HIcon(AppIcon.tick)
                            .font(.callout)
                            .foregroundStyle(Color.dsGreen)
                            .frame(width: 32, height: 32)
                            .background(Color.dsGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                        Text("Device Token")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)

                        Spacer()

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
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
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
            DSBadge(text: NSLocalizedString("settings.notification.denied", comment: ""), color: .dsRed)
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
                HStack(spacing: DS.spacingMD) {
                    HIcon(AppIcon.server)
                        .font(.callout)
                        .foregroundStyle(Color.dsGreen)
                        .frame(width: 32, height: 32)
                        .background(Color.dsGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                    Text(L10n.Settings.serverStatus)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)

                    Spacer()

                    switch serverStatus {
                    case .checking:
                        ProgressView().controlSize(.small)
                    case .online:
                        DSBadge(text: Localized.status("ONLINE"), color: .dsGreen)
                    case .offline:
                        DSBadge(text: Localized.status("OFFLINE"), color: .dsRed)
                    }
                }
                .padding(.vertical, DS.spacingMD)
                .padding(.horizontal, DS.spacingLG)
                .frame(minHeight: DS.minTouchTarget)
                .contentShape(Rectangle())

                DSDivider()

                DSRow(
                    icon: AppIcon.info,
                    iconColor: .dsTextSecondary,
                    title: L10n.Settings.version,
                    trailing: AnyView(Text(appVersion).font(.subheadline.monospaced()).foregroundStyle(Color.dsTextSecondary)),
                    showChevron: false
                )

                DSDivider()

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    DSRow(icon: AppIcon.shield, iconColor: .dsBlue, title: "隐私政策")
                }
                .buttonStyle(.dsPressed)

                DSDivider()

                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    DSRow(icon: AppIcon.profile, iconColor: .dsPurple, title: "用户协议")
                }
                .buttonStyle(.dsPressed)
            }
        }
    }

    // MARK: - Delete Account

    private var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader("删除账户")

            DSDangerButton("删除账户", icon: AppIcon.delete) {
                showDeleteAccountConfirm = true
            }
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

    private func deleteAccount() {
        showDeleteAccountContactAdmin = true
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
            .scrollContentBackground(.hidden)
            .background(Color.dsBackground)
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
                        .foregroundStyle(Color.dsTextSecondary)
                } else if let error = errorMsg {
                    VStack(spacing: DS.spacingLG) {
                        HIcon(AppIcon.warning)
                            .font(.largeTitle)
                            .foregroundStyle(Color.dsOrange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
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
                                HStack(spacing: DS.spacingXS) {
                                    Circle()
                                        .fill(smtp.configured ? Color.dsGreen : Color.dsRed)
                                        .frame(width: 8, height: 8)
                                    Text(smtp.configured ? Localized.status("CONFIGURED") : Localized.status("NOTCONFIGURED"))
                                        .foregroundStyle(smtp.configured ? Color.dsGreen : Color.dsRed)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.dsBackground)
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
                .foregroundStyle(Color.dsTextSecondary)
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
