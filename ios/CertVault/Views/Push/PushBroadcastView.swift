import SwiftUI
import HiconIcons

struct PushBroadcastView: View {
    @StateObject private var vm = PushViewModel()
    private let storage = PushStorage.shared
    @State private var authMode = 0
    @State private var selectedPushKeyId = ""
    @State private var selectedAccountId = ""
    @State private var manualTeamId = ""
    @State private var bundleId = ""
    @State private var title = ""
    @State private var messageBody = ""
    @State private var badge = ""
    @State private var sound = "default"
    @State private var sandbox = true
    @State private var showAdvanced = false
    @State private var threadId = ""
    @State private var collapseId = ""
    @State private var mutableContent = false
    @State private var interruptionLevel = "active"
    @State private var relevanceScore = ""
    @State private var priority = "10"
    @State private var expiration = ""
    @State private var customDataKey = ""
    @State private var customDataValue = ""
    @State private var customData: [String: String] = [:]
    @State private var showTemplateSheet = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var savedBundleIds: [String] = []

    var body: some View {
        Form {
            headerSection
            templateSection
            authSection
            targetSection
            contentSection
            advancedSection
            customDataSection
            sendSection
            resultSection
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("群发推送")
        .glassSheet(isPresented: $showTemplateSheet) {
            BroadcastTemplatePickerSheet(storage: storage) { tpl in
                applyTemplate(tpl)
                showTemplateSheet = false
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
            await vm.loadDeviceStats()
            savedBundleIds = storage.savedBundleIds
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

    // MARK: - Header

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                HIcon(AppIcon.megaphone)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.dsAccentOrange, .dsAccentPink],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("群发推送通知")
                        .font(.headline)
                        .foregroundStyle(Color.dsText)
                    Text("向所有已注册设备发送推送消息")
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)

            if let stats = vm.deviceStats {
                HStack(spacing: 0) {
                    statBadge("总计", value: stats.total?.value ?? 0, color: .dsAccentBlue)
                    Divider().frame(height: 32)
                    statBadge("沙盒", value: stats.sandbox?.value ?? 0, color: .dsAccentOrange)
                    Divider().frame(height: 32)
                    statBadge("生产", value: stats.production?.value ?? 0, color: .dsAccent)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            } else if let count = vm.deviceCount {
                HStack(spacing: 4) {
                    HIcon(AppIcon.iphone)
                        .foregroundStyle(Color.dsAccentBlue)
                    Text("\(count) 台已注册设备")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsText)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Auth

    private var authSection: some View {
        Section("认证方式") {
            Picker("", selection: $authMode) {
                Text("推送密钥").tag(0)
                Text("开发者账号").tag(1)
            }
                    .listRowBackground(Color.clear)
            .pickerStyle(.segmented)

            switch authMode {
            case 0:
                Picker("推送密钥", selection: $selectedPushKeyId) {
                    Text("请选择").tag("")
                    ForEach(vm.pushKeys) { key in
                        Text(key.displayName).tag(key.id)
                    }
                }
                .listRowBackground(Color.clear)
                if vm.pushKeys.isEmpty {
                    HStack(spacing: 4) {
                        HIcon(AppIcon.warning)
                            .font(.caption)
                        Text("暂无推送密钥，请先在「推送密钥」中添加")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.dsAccentOrange)
                    .listRowBackground(Color.clear)
                }
            default:
                Picker("开发者账号", selection: $selectedAccountId) {
                    Text("请选择").tag("")
                    ForEach(vm.accounts) { acc in
                        Text(acc.displayName).tag(acc.id)
                    }
                }
                .listRowBackground(Color.clear)
                TextField("Team ID", text: $manualTeamId)
                    .textInputAutocapitalization(.characters)
                    .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Template

    @ViewBuilder
    private var templateSection: some View {
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
    }

    // MARK: - Target

    private var targetSection: some View {
        Section("推送目标") {
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

            Toggle("沙盒环境", isOn: $sandbox)
                .listRowBackground(Color.clear)

            HStack(spacing: 8) {
                HIcon(AppIcon.info)
                    .foregroundStyle(Color.dsAccentBlue)
                Text("将推送至所有匹配环境的已注册设备")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        Section("推送内容") {
            TextField("标题", text: $title)
                .listRowBackground(Color.clear)
            TextField("消息正文", text: $messageBody, axis: .vertical)
                .lineLimit(2...5)
                .listRowBackground(Color.clear)
            HStack {
                Text("角标")
                Spacer()
                TextField("数字", text: $badge)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            .listRowBackground(Color.clear)
            TextField("声音（default / 自定义文件名）", text: $sound)
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
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        Section {
            DisclosureGroup("高级选项", isExpanded: $showAdvanced) {
                TextField("Thread ID（会话分组）", text: $threadId)
                    .textInputAutocapitalization(.never)
                    .listRowBackground(Color.clear)
                TextField("Collapse ID（合并标识）", text: $collapseId)
                    .textInputAutocapitalization(.never)
                    .listRowBackground(Color.clear)
                Toggle("Mutable Content", isOn: $mutableContent)
                    .listRowBackground(Color.clear)
                Picker("中断级别", selection: $interruptionLevel) {
                    Text("被动 (passive)").tag("passive")
                    Text("活跃 (active)").tag("active")
                    Text("时效 (time-sensitive)").tag("time-sensitive")
                    Text("紧急 (critical)").tag("critical")
                }
                .listRowBackground(Color.clear)
                Picker("优先级", selection: $priority) {
                    Text("10 (立即)").tag("10")
                    Text("5 (省电)").tag("5")
                    Text("1 (低)").tag("1")
                }
                .listRowBackground(Color.clear)
                TextField("Relevance Score (0~1)", text: $relevanceScore)
                    .keyboardType(.decimalPad)
                    .listRowBackground(Color.clear)
                TextField("过期时间（秒）", text: $expiration)
                    .keyboardType(.numberPad)
                    .listRowBackground(Color.clear)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Custom Data

    private var customDataSection: some View {
        Section("自定义数据") {
            ForEach(Array(customData.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(Color.dsAccentPurple)
                    Spacer()
                    Text(customData[key] ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                    Button {
                        customData.removeValue(forKey: key)
                    } label: {
                        HIcon(AppIcon.minusCircle)
                            .foregroundStyle(Color.dsAccentPink)
                    }
                }
                .listRowBackground(Color.clear)
            }

            HStack(spacing: 8) {
                TextField("Key", text: $customDataKey)
                    .textInputAutocapitalization(.never)
                    .frame(maxWidth: .infinity)
                TextField("Value", text: $customDataValue)
                    .frame(maxWidth: .infinity)
                Button {
                    guard !customDataKey.isEmpty else { return }
                    customData[customDataKey] = customDataValue
                    customDataKey = ""
                    customDataValue = ""
                } label: {
                        HIcon(AppIcon.plusCircle)
                        .foregroundStyle(Color.dsAccentBlue)
                }
                .disabled(customDataKey.isEmpty)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Send

    private var sendSection: some View {
        Section {
            Button {
                Task { await sendBroadcast() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isBroadcasting {
                        ProgressView().tint(.white)
                    } else {
                        HIcon(AppIcon.megaphone)
                            .font(.body)
                    }
                    Text("发送群发推送")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(canSend ? .white : Color.dsMuted)
                .background(
                    canSend ? Color.dsAccentOrange : Color.dsSurfaceLight,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .disabled(!canSend || vm.isBroadcasting)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        if let result = vm.sendResult {
            Section("推送结果") {
                Text(result)
                    .font(.subheadline)
                    .foregroundStyle(result.contains("完成") ? Color.dsAccent : Color.dsAccentPink)
                    .listRowBackground(Color.clear)

                if let br = vm.broadcastResult {
                    HStack(spacing: 0) {
                        statBadge("总计", value: br.total?.value ?? 0, color: .dsAccentBlue)
                        Divider().frame(height: 40)
                        statBadge("成功", value: br.success?.value ?? 0, color: .dsAccent)
                        Divider().frame(height: 40)
                        statBadge("失败", value: br.failed?.value ?? 0, color: .dsAccentPink)
                        if let unreg = br.unregistered, unreg.value > 0 {
                            Divider().frame(height: 40)
                            statBadge("注销", value: unreg.value, color: .dsAccentOrange)
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
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var canSend: Bool {
        guard !bundleId.isEmpty, !title.isEmpty else { return false }
        switch authMode {
        case 0: return !selectedPushKeyId.isEmpty
        default: return !selectedAccountId.isEmpty && !manualTeamId.isEmpty
        }
    }

    private func sendBroadcast() async {
        storage.saveBundleId(bundleId)
        savedBundleIds = storage.savedBundleIds

        var request = BroadcastRequest(
            title: title,
            body: messageBody.isEmpty ? nil : messageBody,
            badge: Int(badge),
            sound: sound.isEmpty ? nil : sound,
            bundle_id: bundleId,
            sandbox: sandbox,
            custom_data: customData.isEmpty ? nil : customData,
            thread_id: threadId.isEmpty ? nil : threadId,
            collapse_id: collapseId.isEmpty ? nil : collapseId,
            mutable_content: mutableContent ? true : nil,
            interruption_level: interruptionLevel == "active" ? nil : interruptionLevel,
            relevance_score: Double(relevanceScore),
            priority: Int(priority) == 10 ? nil : Int(priority),
            expiration: expiration.isEmpty ? nil : expiration
        )

        switch authMode {
        case 0: request.push_key_id = selectedPushKeyId
        default: request.account_id = selectedAccountId; request.team_id = manualTeamId
        }

        await vm.broadcast(request: request)
    }

    private func statBadge(_ label: String, value: Int, color: Color) -> some View {
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

// MARK: - Template Picker

private struct BroadcastTemplatePickerSheet: View {
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
