import SwiftUI
import HiconIcons
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var appearance: AppearanceManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var showChangePassword = false
    @State private var showLogoutConfirm = false
    @State private var showSMTP = false
    @State private var serverStatus: ServerStatus = .checking

    private enum ServerStatus {
        case checking, online(String), offline
    }

    private var roleDisplayName: String {
        switch authVM.role {
        case "superadmin": return "超级管理员"
        case "admin": return "管理员"
        default: return "用户"
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
                notificationSection
                aboutSection
                logoutSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle("设置")
        .alert("确认退出", isPresented: $showLogoutConfirm) {
            Button("退出", role: .destructive) {
                Task { await authVM.logout() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后需要重新登录")
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet()
        }
        .task { await checkServerHealth() }
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
            sectionHeader("管理")

            NavigationLink {
                UserManagementView()
            } label: {
                HStack(spacing: 12) {
                    HIcon(AppIcon.group)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentPurple)
                        .frame(width: 20)
                    Text("用户管理")
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
                    Text("邮件服务配置")
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
            sectionHeader("外观")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(appearance.mode == .dark ? AppIcon.moon : appearance.mode == .light ? AppIcon.sun : AppIcon.settings)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentPurple)
                        .frame(width: 20)
                    Text("显示模式")
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
            sectionHeader("安全")

            Button { showChangePassword = true } label: {
                HStack(spacing: 12) {
                    HIcon(AppIcon.lock)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentOrange)
                        .frame(width: 20)
                    Text("修改密码")
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

    // MARK: - Notifications

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("推送通知")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(AppIcon.pushKey)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentBlue)
                        .frame(width: 20)
                    Text("通知权限")
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
                            Text("前往系统设置开启")
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
                            Text("开启推送通知")
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
                            Text("等待注册")
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
                Text("已开启")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsAccent)
            }
        case .denied:
            HStack(spacing: 6) {
                Circle().fill(Color.dsAccentPink).frame(width: 8, height: 8)
                Text("已关闭")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsAccentPink)
            }
        case .provisional:
            HStack(spacing: 6) {
                Circle().fill(Color.dsAccentOrange).frame(width: 8, height: 8)
                Text("临时授权")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsAccentOrange)
            }
        default:
            HStack(spacing: 6) {
                Circle().fill(Color.dsMuted).frame(width: 8, height: 8)
                Text("未设置")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("关于")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HIcon(AppIcon.server)
                        .font(.body)
                        .foregroundStyle(Color.dsAccent)
                        .frame(width: 20)
                    Text("服务器状态")
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
                            Text("在线")
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccent)
                        }
                    case .offline:
                        HStack(spacing: 6) {
                            Circle().fill(Color.dsAccentPink).frame(width: 8, height: 8)
                            Text("离线")
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
                    Text("版本")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    Text(appVersion)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.dsMuted)
                }
                .padding(14)
            }
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
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
                Text("退出登录")
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
                    SecureField("当前密码", text: $oldPassword)
                    SecureField("新密码", text: $newPassword)
                    SecureField("确认新密码", text: $confirmPassword)
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") { save() }
                        .disabled(!isValid || isLoading)
                }
            }
            .alert("修改成功", isPresented: $success) {
                Button("好") { dismiss() }
            } message: {
                Text("密码已更新，下次登录请使用新密码")
            }
        }
        .presentationDetents([.medium])
    }

    private var isValid: Bool {
        !oldPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func save() {
        guard newPassword == confirmPassword else {
            errorMsg = "两次密码输入不一致"
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
                    ProgressView("加载中...")
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
                        Section("连接信息") {
                            row("SMTP 主机", smtp.host.isEmpty ? "未配置" : smtp.host)
                            row("端口", smtp.port)
                            row("SSL/TLS", smtp.secure == "true" ? "已启用" : "未启用")
                        }
                        Section("账号") {
                            row("发件人", smtp.user.isEmpty ? "未配置" : smtp.user)
                        }
                        Section("状态") {
                            HStack {
                                Text("邮件服务")
                                    .foregroundStyle(Color.dsText)
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(smtp.configured ? Color.dsAccent : Color.dsAccentPink)
                                        .frame(width: 8, height: 8)
                                    Text(smtp.configured ? "已配置" : "未配置")
                                        .foregroundStyle(smtp.configured ? Color.dsAccent : Color.dsAccentPink)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("邮件服务配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
