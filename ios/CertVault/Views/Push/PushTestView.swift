import SwiftUI
import HiconIcons

struct PushTestView: View {
    @StateObject private var vm = PushViewModel()
    @EnvironmentObject private var notificationManager: NotificationManager
    private let storage = PushStorage.shared
    @State private var pushMode = 0  // 0=单设备, 1=广播
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
    @State private var showAdvanced = false
    @State private var threadId = ""
    @State private var collapseId = ""
    @State private var mutableContent = false
    @State private var interruptionLevel = "active"
    @State private var relevanceScore = ""
    @State private var priority = "10"
    @State private var expiration = ""
    @State private var showTemplateSheet = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var savedBundleIds: [String] = []
    @State private var showDevicePicker = false

    var body: some View {
        Form {
            Section {
                Picker("推送模式", selection: $pushMode) {
                    HStack(spacing: 4) {
                        HIcon(AppIcon.person)
                        Text("单设备")
                    }.tag(0)
                    HStack(spacing: 4) {
                        HIcon(AppIcon.megaphone)
                        Text("广播")
                        if let count = vm.deviceCount {
                            Text("(\(count)台)")
                                .foregroundStyle(Color.dsMuted)
                        }
                    }.tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            if !storage.savedTemplates.isEmpty {
                Section {
                    Button {
                        showTemplateSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            HIcon(AppIcon.docText)
                                .foregroundStyle(Color.dsAccentPurple)
                            Text("使用模板")
                                .foregroundStyle(Color.dsText)
                            Spacer()
                            Text("\(storage.savedTemplates.count) 个")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                            HIcon(AppIcon.chevronRight)
                                .font(.caption2)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Section(NSLocalizedString("push.test.section.auth", comment: "")) {
                Picker("", selection: $authMode) {
                    Text(L10n.Push.testKeyTab).tag(0)
                    Text(L10n.Push.testAccountTab).tag(1)
                    Text(L10n.Push.testManualTab).tag(2)
                }
                    .listRowBackground(Color.clear)
                .pickerStyle(.segmented)

                switch authMode {
                case 0:
                    Picker(L10n.Push.testKeyTab, selection: $selectedPushKeyId) {
                        Text(L10n.select).tag("")
                        ForEach(vm.pushKeys) { key in
                            Text(key.displayName).tag(key.id)
                        }
                    }
                    .listRowBackground(Color.clear)
                case 1:
                    Picker(L10n.account, selection: $selectedAccountId) {
                        Text(L10n.select).tag("")
                        ForEach(vm.accounts) { acc in
                            Text(acc.displayName).tag(acc.id)
                        }
                    }
                    .listRowBackground(Color.clear)
                    TextField("Team ID", text: $manualTeamId)
                        .textInputAutocapitalization(.characters)
                        .listRowBackground(Color.clear)
                default:
                    TextField("Key ID", text: $manualKeyId)
                        .textInputAutocapitalization(.characters)
                        .listRowBackground(Color.clear)
                    TextField("Team ID", text: $manualTeamId)
                        .textInputAutocapitalization(.characters)
                        .listRowBackground(Color.clear)
                    TextEditor(text: $manualPrivateKey)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .listRowBackground(Color.clear)
                }
            }

            Section(NSLocalizedString("push.test.section.target", comment: "")) {
                if pushMode == 0 {
                    HStack {
                        TextField("Device Token", text: $deviceToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button { showDevicePicker = true } label: {
                            HIcon(AppIcon.checklist)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccentBlue)
                        }
                        Button { showTokenGuide = true } label: {
                            HIcon(AppIcon.info)
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    .listRowBackground(Color.clear)

                    if notificationManager.deviceToken != nil && deviceToken == notificationManager.deviceToken {
                        Text(L10n.Push.testAutoFill)
                            .font(.caption2)
                            .foregroundStyle(Color.dsAccent)
                            .listRowBackground(Color.clear)
                    } else if deviceToken.isEmpty {
                        HStack(spacing: 12) {
                            if notificationManager.deviceToken != nil {
                                Button {
                                    deviceToken = notificationManager.deviceToken!
                                } label: {
                                    HStack(spacing: 4) {
                                        HIcon(AppIcon.pushKey).font(.caption2)
                                        Text(NSLocalizedString("push.test.fillToken", comment: ""))
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(Color.dsAccentBlue)
                                }
                            }

                            Button {
                                showDevicePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    HIcon(AppIcon.iphone)
                                        .font(.caption2)
                                    Text("从设备列表选择")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.dsAccentPurple)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    HStack(spacing: 8) {
                        HIcon(AppIcon.megaphone)
                            .foregroundStyle(Color.dsAccentOrange)
                        Text("将推送到所有已注册设备")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsText)
                        Spacer()
                        if let count = vm.deviceCount {
                            Text("\(count) 台")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dsAccentBlue)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                if savedBundleIds.isEmpty {
                    TextField("Bundle ID", text: $bundleId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .listRowBackground(Color.clear)
                } else {
                    HStack {
                        TextField("Bundle ID", text: $bundleId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Menu {
                            ForEach(savedBundleIds, id: \.self) { bid in
                                Button(bid) { bundleId = bid }
                            }
                            Divider()
                            Button("清除历史", role: .destructive) {
                                savedBundleIds.forEach { storage.removeBundleId($0) }
                                savedBundleIds = []
                            }
                        } label: {
                            HIcon(AppIcon.clock)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccentBlue)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Toggle(NSLocalizedString("push.test.sandbox", comment: ""), isOn: $sandbox)
                    .listRowBackground(Color.clear)
            }

            Section(NSLocalizedString("push.test.section.content", comment: "")) {
                TextField(NSLocalizedString("push.test.field.title", comment: ""), text: $title)
                    .listRowBackground(Color.clear)
                TextField(NSLocalizedString("push.test.field.body", comment: ""), text: $messageBody)
                    .listRowBackground(Color.clear)
                TextField(NSLocalizedString("push.test.field.badge", comment: ""), text: $badge)
                    .keyboardType(.numberPad)
                    .listRowBackground(Color.clear)
                TextField(NSLocalizedString("push.test.field.sound", comment: ""), text: $sound)
                    .listRowBackground(Color.clear)

                Button {
                    showSaveTemplate = true
                    templateName = title
                } label: {
                    HStack(spacing: 4) {
                        HIcon(AppIcon.download)
                        Text("保存为模板")
                    }
                    .font(.caption)
                    .foregroundStyle(title.isEmpty ? Color.dsMuted : Color.dsAccentBlue)
                }
                .disabled(title.isEmpty)
                .listRowBackground(Color.clear)
            }

            Section {
                DisclosureGroup("高级选项", isExpanded: $showAdvanced) {
                    TextField("Thread ID（会话分组）", text: $threadId)
                        .textInputAutocapitalization(.never)
                    TextField("Collapse ID（合并标识）", text: $collapseId)
                        .textInputAutocapitalization(.never)
                    Toggle("Mutable Content", isOn: $mutableContent)
                    Picker("中断级别", selection: $interruptionLevel) {
                        Text("被动 (passive)").tag("passive")
                        Text("活跃 (active)").tag("active")
                        Text("时效 (time-sensitive)").tag("time-sensitive")
                        Text("紧急 (critical)").tag("critical")
                    }
                    Picker("优先级", selection: $priority) {
                        Text("10 (立即)").tag("10")
                        Text("5 (省电)").tag("5")
                        Text("1 (低)").tag("1")
                    }
                    TextField("Relevance Score (0~1)", text: $relevanceScore)
                        .keyboardType(.decimalPad)
                    TextField("过期时间（秒）", text: $expiration)
                        .keyboardType(.numberPad)
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    Task {
                        if pushMode == 1 {
                            await sendBroadcast()
                        } else {
                            await send()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isSending || vm.isBroadcasting {
                            ProgressView().tint(.white)
                        } else {
                            HIcon(AppIcon.pushTest).font(.body)
                        }
                        Text(pushMode == 1 ? "发送广播" : L10n.Push.testSend)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(isSendButtonEnabled ? Color.white : Color.dsMuted)
                    .background(
                        isSendButtonEnabled ? (pushMode == 1 ? Color.dsAccentOrange : Color.dsAccentBlue) : Color.dsSurfaceLight,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .disabled(!isSendButtonEnabled)
            }

            if let result = vm.sendResult {
                Section(NSLocalizedString("push.test.section.result", comment: "")) {
                    Text(result)
                        .font(.subheadline)
                        .foregroundStyle(result.contains("成功") || result.contains("完成") ? Color.dsAccent : Color.dsAccentPink)
                        .listRowBackground(Color.clear)

                    if let br = vm.broadcastResult {
                        HStack(spacing: 16) {
                            broadcastStatBadge("总计", value: br.total?.value ?? 0, color: .dsAccentBlue)
                            broadcastStatBadge("成功", value: br.success?.value ?? 0, color: .dsAccent)
                            broadcastStatBadge("失败", value: br.failed?.value ?? 0, color: .dsAccentPink)
                            if let unreg = br.unregistered, unreg.value > 0 {
                                broadcastStatBadge("注销", value: unreg.value, color: .dsAccentOrange)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)

                        if let errs = br.errors, !errs.isEmpty {
                            DisclosureGroup("失败详情 (\(errs.count))") {
                                ForEach(errs) { err in
                                    HStack {
                                        Text(err.token?.prefix(16).appending("...") ?? "-")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(Color.dsMuted)
                                        Spacer()
                                        Text(err.reason ?? "未知")
                                            .font(.caption)
                                            .foregroundStyle(Color.dsAccentPink)
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle(L10n.Push.testTitle)
        .glassSheet(isPresented: $showTokenGuide) {
            TokenGuideSheet()
        }
        .glassSheet(isPresented: $showTemplateSheet) {
            PushTemplatePickerSheet(storage: storage) { tpl in
                applyTemplate(tpl)
                showTemplateSheet = false
            }
        }
        .glassSheet(isPresented: $showDevicePicker) {
            DevicePickerSheet(vm: vm) { selected in
                deviceToken = selected.device_token ?? ""
                if let isSandbox = selected.sandbox {
                    sandbox = isSandbox
                }
                showDevicePicker = false
            }
        }
        .alert("保存模板", isPresented: $showSaveTemplate) {
            TextField("模板名称", text: $templateName)
            Button("保存") {
                let tpl = PushTemplate(
                    name: templateName,
                    title: title,
                    body: messageBody,
                    badge: Int(badge),
                    sound: sound.isEmpty ? nil : sound,
                    threadId: threadId.isEmpty ? nil : threadId,
                    collapseId: collapseId.isEmpty ? nil : collapseId,
                    mutableContent: mutableContent ? true : nil,
                    interruptionLevel: interruptionLevel == "active" ? nil : interruptionLevel,
                    priority: priority == "10" ? nil : priority
                )
                storage.saveTemplate(tpl)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将当前推送内容保存为模板，方便下次快速使用")
        }
        .task {
            await vm.loadKeys()
            await vm.loadAccounts()
            await vm.loadDeviceCount()
            await vm.loadDevices()
            savedBundleIds = storage.savedBundleIds
            if deviceToken.isEmpty, let token = notificationManager.deviceToken {
                deviceToken = token
            }
        }
    }

    private func applyTemplate(_ tpl: PushTemplate) {
        title = tpl.title
        messageBody = tpl.body
        badge = tpl.badge.map { "\($0)" } ?? ""
        sound = tpl.sound ?? "default"
        threadId = tpl.threadId ?? ""
        collapseId = tpl.collapseId ?? ""
        mutableContent = tpl.mutableContent ?? false
        interruptionLevel = tpl.interruptionLevel ?? "active"
        priority = tpl.priority ?? "10"
    }

    private var canSend: Bool {
        guard !bundleId.isEmpty else { return false }
        if pushMode == 0 && deviceToken.isEmpty { return false }
        switch authMode {
        case 0: return !selectedPushKeyId.isEmpty
        case 1: return !selectedAccountId.isEmpty && !manualTeamId.isEmpty
        default: return !manualKeyId.isEmpty && !manualTeamId.isEmpty && !manualPrivateKey.isEmpty
        }
    }

    private var isSendButtonEnabled: Bool {
        canSend && !vm.isSending && !vm.isBroadcasting
    }

    private var advancedOptions: (threadId: String?, collapseId: String?, mutableContent: Bool?, interruptionLevel: String?, relevanceScore: Double?, priority: Int?, expiration: String?) {
        (
            threadId.isEmpty ? nil : threadId,
            collapseId.isEmpty ? nil : collapseId,
            mutableContent ? true : nil,
            interruptionLevel == "active" ? nil : interruptionLevel,
            Double(relevanceScore),
            Int(priority) == 10 ? nil : Int(priority),
            expiration.isEmpty ? nil : expiration
        )
    }

    private func send() async {
        storage.saveBundleId(bundleId)
        savedBundleIds = storage.savedBundleIds

        let adv = advancedOptions
        var request = PushRequest(
            device_token: deviceToken,
            bundle_id: bundleId,
            title: title,
            body: messageBody,
            badge: Int(badge),
            sound: sound.isEmpty ? nil : sound,
            sandbox: sandbox,
            thread_id: adv.threadId,
            collapse_id: adv.collapseId,
            mutable_content: adv.mutableContent,
            interruption_level: adv.interruptionLevel,
            relevance_score: adv.relevanceScore,
            priority: adv.priority,
            expiration: adv.expiration
        )

        switch authMode {
        case 0: request.push_key_id = selectedPushKeyId
        case 1: request.account_id = selectedAccountId; request.team_id = manualTeamId
        default: request.key_id = manualKeyId; request.team_id = manualTeamId; request.private_key = manualPrivateKey
        }

        await vm.send(request: request)
    }

    private func sendBroadcast() async {
        storage.saveBundleId(bundleId)
        savedBundleIds = storage.savedBundleIds

        let adv = advancedOptions
        var request = BroadcastRequest(
            title: title,
            body: messageBody,
            badge: Int(badge),
            sound: sound.isEmpty ? nil : sound,
            bundle_id: bundleId,
            sandbox: sandbox,
            thread_id: adv.threadId,
            collapse_id: adv.collapseId,
            mutable_content: adv.mutableContent,
            interruption_level: adv.interruptionLevel,
            relevance_score: adv.relevanceScore,
            priority: adv.priority,
            expiration: adv.expiration
        )

        switch authMode {
        case 0: request.push_key_id = selectedPushKeyId
        case 1: request.account_id = selectedAccountId; request.team_id = manualTeamId
        default: break
        }

        await vm.broadcast(request: request)
    }

    private func broadcastStatBadge(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Device Picker

private struct DevicePickerSheet: View {
    @ObservedObject var vm: PushViewModel
    let onSelect: (PushDevice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredDevices: [PushDevice] {
        if searchText.isEmpty { return vm.devices }
        let q = searchText.lowercased()
        return vm.devices.filter {
            ($0.device_token ?? "").lowercased().contains(q) ||
            ($0.label ?? "").lowercased().contains(q) ||
            ($0.username ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if vm.devices.isEmpty {
                    VStack(spacing: 12) {
                        HIcon(AppIcon.iphoneSlash)
                            .font(.system(size: 32))
                            .foregroundStyle(Color.dsMuted)
                        Text("暂无已注册设备")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                        Text("设备注册推送后会出现在这里")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(filteredDevices, id: \.stableId) { device in
                        Button {
                            onSelect(device)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    if let label = device.label, !label.isEmpty {
                                        Text(label)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.dsText)
                                            .lineLimit(1)
                                    } else {
                                        Text(device.displayToken)
                                            .font(.subheadline.monospaced())
                                            .foregroundStyle(Color.dsText)
                                    }

                                    Spacer()

                                    Text(device.envLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent, in: RoundedRectangle(cornerRadius: 4))
                                }

                                HStack(spacing: 8) {
                                    if let label = device.label, !label.isEmpty {
                                        Text(device.displayToken)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(Color.dsMuted)
                                    }

                                    if let user = device.username, !user.isEmpty {
                                        HStack(spacing: 2) {
                                            HIcon(AppIcon.person)
                                                .font(.system(size: 8))
                                            Text(user)
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsAccentBlue)
                                    }

                                    Spacer()

                                    if let platform = device.platform {
                                        Text(platform.uppercased())
                                            .font(.caption2)
                                            .foregroundStyle(Color.dsMuted)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .tint(Color.dsText)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索设备")
            .navigationTitle("选择设备 (\(vm.devices.count))")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                if vm.devices.isEmpty { await vm.loadDevices() }
            }
        }
        .sheetStyle()
    }
}

// MARK: - Template Picker

private struct PushTemplatePickerSheet: View {
    let storage: PushStorage
    let onSelect: (PushTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    private var customTemplates: [PushTemplate] {
        storage.savedTemplates.filter { !$0.id.hasPrefix("builtin_") }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("内置模板") {
                    ForEach(PushStorage.builtInTemplates) { tpl in
                        templateRow(tpl, deletable: false)
                    }
                }

                if !customTemplates.isEmpty {
                    Section("自定义模板") {
                        ForEach(customTemplates) { tpl in
                            templateRow(tpl, deletable: true)
                        }
                    }
                }
            }
            .navigationTitle("选择模板")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .sheetStyle()
    }

    private func templateRow(_ tpl: PushTemplate, deletable: Bool) -> some View {
        Button {
            onSelect(tpl)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(tpl.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                if !tpl.body.isEmpty {
                    Text(tpl.body)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let s = tpl.sound, !s.isEmpty {
                        Label(s, systemImage: "speaker.wave.2")
                    }
                    if tpl.sound == nil {
                        Label("静默", systemImage: "speaker.slash")
                    }
                    if let b = tpl.badge {
                        Label("\(b)", systemImage: "app.badge")
                    }
                    if let level = tpl.interruptionLevel {
                        Label(level, systemImage: "bell")
                    }
                    if let p = tpl.priority, p != "10" {
                        Label("优先级 \(p)", systemImage: "arrow.up.arrow.down")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
            }
            .padding(.vertical, 2)
        }
        .swipeActions(edge: .trailing) {
            if deletable {
                Button(role: .destructive) {
                    storage.deleteTemplate(id: tpl.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Token Guide

private struct TokenGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    guideSection(
                        number: "1",
                        title: NSLocalizedString("push.token.auto.title", comment: ""),
                        color: .dsAccent,
                        steps: [
                            "打开「设置 → 推送通知」，确认权限已开启",
                            "CertVault 启动时会自动注册并获取 Device Token",
                            "回到推送测试页面，Token 会自动填入",
                        ]
                    )

                    guideSection(
                        number: "2",
                        title: NSLocalizedString("push.token.xcode.title", comment: ""),
                        color: .dsAccentBlue,
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
                        color: .dsAccentPurple,
                        steps: [
                            "在 AppDelegate 的 didRegisterForRemoteNotifications 中打印 token",
                            "将 Data 转为十六进制: token.map { String(format: \"%02x\", $0) }.joined()",
                            "运行 App 后在控制台查看输出",
                        ]
                    )

                    tipsCard
                }
                .padding(16)
            }
            .navigationTitle(L10n.Push.tokenTitle)
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            HIcon(AppIcon.pushKey)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(colors: [.dsAccentBlue, .dsAccentPurple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text(L10n.Push.tokenDesc)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(cornerRadius: 16)
    }

    private func guideSection(number: String, title: String, color: Color, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color, in: Circle())

                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.dsText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1).")
                            .font(.caption.monospaced())
                            .foregroundStyle(color)
                            .frame(width: 18, alignment: .trailing)
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(Color.dsText.opacity(0.85))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 12)
        }
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HIcon(AppIcon.warning)
                    .font(.caption)
                    .foregroundStyle(Color.dsAccentOrange)
                Text(L10n.Push.tokenNotes)
                    .font(.caption.bold())
                    .foregroundStyle(Color.dsAccentOrange)
            }

            VStack(alignment: .leading, spacing: 6) {
                tipRow("模拟器无法获取 Token，需要真机运行")
                tipRow("沙盒 Token 和生产 Token 不同，注意环境选择")
                tipRow("Token 可能因系统更新或重装 App 而变化")
                tipRow("Token 长度通常为 64 个十六进制字符")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dsAccentOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsAccentOrange.opacity(0.2), lineWidth: 1)
        )
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
                .foregroundStyle(Color.dsAccentOrange)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.dsText.opacity(0.8))
        }
    }
}
