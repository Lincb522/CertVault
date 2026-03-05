import SwiftUI
import HiconIcons

struct PushTestView: View {
    @StateObject private var vm = PushViewModel()
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var authMode = 0
    @State private var selectedPushKeyId = ""
    @State private var selectedAccountId = ""
    @State private var manualTeamId = ""
    @State private var manualKeyId = ""
    @State private var manualPrivateKey = ""
    @State private var deviceToken = ""
    @State private var bundleId = ""
    @State private var title = ""
    @State private var messageBody = ""
    @State private var badge = ""
    @State private var sound = "default"
    @State private var sandbox = true
    @State private var showTokenGuide = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacing2XL) {
                authSection
                targetSection
                contentSection
                sendButton
                if let result = vm.sendResult {
                    resultSection(result)
                }
            }
            .padding(DS.spacingLG)
        }
        .pageBackground()
        .navigationTitle(L10n.Push.testTitle)
        .sheet(isPresented: $showTokenGuide) {
            TokenGuideSheet()
        }
        .task {
            await vm.loadKeys()
            await vm.loadAccounts()
            if deviceToken.isEmpty, let token = notificationManager.deviceToken {
                deviceToken = token
            }
        }
    }

    private var authSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                DSSectionHeader(NSLocalizedString("push.test.section.auth", comment: ""))

                Picker("", selection: $authMode) {
                    Text(L10n.Push.testKeyTab).tag(0)
                    Text(L10n.Push.testAccountTab).tag(1)
                    Text(L10n.Push.testManualTab).tag(2)
                }
                .pickerStyle(.segmented)

                switch authMode {
                case 0:
                    Picker(L10n.Push.testKeyTab, selection: $selectedPushKeyId) {
                        Text(L10n.select).tag("")
                        ForEach(vm.pushKeys) { key in
                            Text(key.displayName).tag(key.id)
                        }
                    }
                case 1:
                    Picker(L10n.account, selection: $selectedAccountId) {
                        Text(L10n.select).tag("")
                        ForEach(vm.accounts) { acc in
                            Text(acc.displayName).tag(acc.id)
                        }
                    }
                    TextField("Team ID", text: $manualTeamId)
                        .textInputAutocapitalization(.characters)
                        .foregroundStyle(Color.dsText)
                default:
                    TextField("Key ID", text: $manualKeyId)
                        .textInputAutocapitalization(.characters)
                        .foregroundStyle(Color.dsText)
                    TextField("Team ID", text: $manualTeamId)
                        .textInputAutocapitalization(.characters)
                        .foregroundStyle(Color.dsText)
                    TextEditor(text: $manualPrivateKey)
                        .font(.dsMono)
                        .foregroundStyle(Color.dsText)
                        .frame(minHeight: 80)
                }
            }
            .padding(DS.spacingLG)
        }
    }

    private var targetSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                DSSectionHeader(NSLocalizedString("push.test.section.target", comment: ""))

                HStack(spacing: DS.spacingMD) {
                    TextField("Device Token", text: $deviceToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Color.dsText)
                    Button { showTokenGuide = true } label: {
                        HIcon(AppIcon.info)
                            .font(.caption)
                            .foregroundStyle(Color.dsBrand)
                    }
                    .buttonStyle(.plain)
                }

                if notificationManager.deviceToken != nil && deviceToken == notificationManager.deviceToken {
                    Text(L10n.Push.testAutoFill)
                        .font(.caption2)
                        .foregroundStyle(Color.dsSuccess)
                } else if deviceToken.isEmpty {
                    Button {
                        if let token = notificationManager.deviceToken {
                            deviceToken = token
                        } else {
                            showTokenGuide = true
                        }
                    } label: {
                        HStack(spacing: DS.spacingXS) {
                            HIcon(AppIcon.pushKey).font(.caption2)
                            Text(notificationManager.deviceToken != nil ? NSLocalizedString("push.test.fillToken", comment: "") : NSLocalizedString("push.test.howToGetToken", comment: ""))
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.dsBrand)
                    }
                    .buttonStyle(.plain)
                }

                TextField("Bundle ID", text: $bundleId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.dsText)

                Toggle(NSLocalizedString("push.test.sandbox", comment: ""), isOn: $sandbox)
                    .tint(Color.dsBrand)
            }
            .padding(DS.spacingLG)
        }
    }

    private var contentSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                DSSectionHeader(NSLocalizedString("push.test.section.content", comment: ""))

                TextField(NSLocalizedString("push.test.field.title", comment: ""), text: $title)
                    .foregroundStyle(Color.dsText)
                TextField(NSLocalizedString("push.test.field.body", comment: ""), text: $messageBody)
                    .foregroundStyle(Color.dsText)
                TextField(NSLocalizedString("push.test.field.badge", comment: ""), text: $badge)
                    .keyboardType(.numberPad)
                    .foregroundStyle(Color.dsText)
                TextField(NSLocalizedString("push.test.field.sound", comment: ""), text: $sound)
                    .foregroundStyle(Color.dsText)
            }
            .padding(DS.spacingLG)
        }
    }

    private var sendButton: some View {
        DSPrimaryButton(title: L10n.Push.testSend, isLoading: vm.isSending, isDisabled: vm.isSending || !canSend) {
            Task { await send() }
        }
    }

    private func resultSection(_ result: String) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("push.test.section.result", comment: ""))
            Text(result)
                .font(.subheadline)
                .foregroundStyle(result.contains("成功") ? Color.dsSuccess : Color.dsDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.spacingLG)
        .cardStyle()
    }

    private var canSend: Bool {
        guard !deviceToken.isEmpty, !bundleId.isEmpty else { return false }
        switch authMode {
        case 0: return !selectedPushKeyId.isEmpty
        case 1: return !selectedAccountId.isEmpty && !manualTeamId.isEmpty
        default: return !manualKeyId.isEmpty && !manualTeamId.isEmpty && !manualPrivateKey.isEmpty
        }
    }

    private func send() async {
        var request = PushRequest(
            device_token: deviceToken,
            bundle_id: bundleId,
            title: title,
            body: messageBody,
            badge: Int(badge),
            sound: sound.isEmpty ? nil : sound,
            sandbox: sandbox
        )

        switch authMode {
        case 0:
            request.push_key_id = selectedPushKeyId
        case 1:
            request.account_id = selectedAccountId
            request.team_id = manualTeamId
        default:
            request.key_id = manualKeyId
            request.team_id = manualTeamId
            request.private_key = manualPrivateKey
        }

        await vm.send(request: request)
    }
}

// MARK: - Token Guide

private struct TokenGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.spacingXL) {
                    headerCard

                    guideSection(
                        number: "1",
                        title: NSLocalizedString("push.token.auto.title", comment: ""),
                        color: .dsSuccess,
                        steps: [
                            "打开「设置 → 推送通知」，确认权限已开启",
                            "CertVault 启动时会自动注册并获取 Device Token",
                            "回到推送测试页面，Token 会自动填入",
                        ]
                    )

                    guideSection(
                        number: "2",
                        title: NSLocalizedString("push.token.xcode.title", comment: ""),
                        color: .dsBlue,
                        steps: [
                            "在 Xcode 中运行你的目标 App",
                            "App 启动后请求推送权限并同意",
                            "在 Xcode 控制台搜索 \"deviceToken\" 或 \"APNs\"",
                            "复制输出的十六进制字符串（64 位）",
                        ]
                    )

                    guideSection(
                        number: "3",
                        title: NSLocalizedString("push.token.code.title", comment: ""),
                        color: .dsPurple,
                        steps: [
                            "在 AppDelegate 的 didRegisterForRemoteNotifications 中打印 token",
                            "将 Data 转为十六进制: token.map { String(format: \"%02x\", $0) }.joined()",
                            "运行 App 后在控制台查看输出",
                        ]
                    )

                    tipsCard
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(L10n.Push.tokenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var headerCard: some View {
        VStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.pushKey)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(colors: [.dsBlue, .dsPurple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text(L10n.Push.tokenDesc)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.spacingXL)
        .cardStyle()
    }

    private func guideSection(number: String, title: String, color: Color, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            HStack(spacing: DS.spacingMD) {
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color, in: Circle())

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.dsText)
            }

            VStack(alignment: .leading, spacing: DS.spacingSM) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: DS.spacingMD) {
                        Text("\(idx + 1).")
                            .font(.dsMono)
                            .foregroundStyle(color)
                            .frame(width: 18, alignment: .trailing)
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
            }
            .padding(DS.spacingLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusMD)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            HStack(spacing: DS.spacingXS) {
                HIcon(AppIcon.warning)
                    .font(.caption)
                    .foregroundStyle(Color.dsWarning)
                Text(L10n.Push.tokenNotes)
                    .font(.caption.bold())
                    .foregroundStyle(Color.dsWarning)
            }

            VStack(alignment: .leading, spacing: DS.spacingXS) {
                tipRow("模拟器无法获取 Token，需要真机运行")
                tipRow("沙盒 Token 和生产 Token 不同，注意环境选择")
                tipRow("Token 可能因系统更新或重装 App 而变化")
                tipRow("Token 长度通常为 64 个十六进制字符")
            }
        }
        .padding(DS.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsWarning.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMD)
                .stroke(Color.dsWarning.opacity(0.2), lineWidth: 1)
        )
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.spacingSM) {
            Text("•")
                .font(.caption)
                .foregroundStyle(Color.dsWarning)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }
}
