import SwiftUI
import HiconIcons

struct PushSettingsView: View {
    @StateObject private var vm = PushViewModel()
    @State private var pushEnabled = false
    @State private var defaultPushKeyId = ""
    @State private var defaultBundleId = ""
    @State private var defaultSandbox = false
    @State private var maxConcurrency = "10"
    @State private var autoCleanup = false
    @State private var historyRetentionDays = "30"
    @State private var tfAutoPushEnabled = false
    @State private var tfAutoPushTitle = ""
    @State private var tfAutoPushBody = ""
    @State private var tfAutoPushGroupId = ""
    @State private var tfAutoPushBundleId = ""
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var selectedAccountIdForTF = ""

    var body: some View {
        Form {
            statusSection
            settingsSection
            saveSection
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("推送设置")
        .task {
            await vm.loadSettings()
            await vm.loadStatus()
            await vm.loadKeys()
            await vm.loadAccounts()
            applySettings()
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let status = vm.pushStatus {
            Section {
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill((status.push_enabled == true ? Color.dsAccent : Color.dsAccentPink).opacity(0.12))
                            .frame(width: 44, height: 44)
                        HIcon(status.push_enabled == true ? AppIcon.check : AppIcon.close)
                            .font(.body)
                            .foregroundStyle(status.push_enabled == true ? Color.dsAccent : Color.dsAccentPink)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("推送服务")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dsText)
                        Text(status.push_enabled == true ? "运行中" : "未启用")
                            .font(.caption)
                            .foregroundStyle(status.push_enabled == true ? Color.dsAccent : Color.dsAccentPink)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let dc = status.device_count {
                            HStack(spacing: 3) {
                                Text("\(dc)").font(.caption.weight(.bold).monospacedDigit())
                                Text("设备").font(.caption2)
                            }
                            .foregroundStyle(Color.dsAccentBlue)
                        }
                        if let kc = status.key_count {
                            HStack(spacing: 3) {
                                Text("\(kc)").font(.caption.weight(.bold).monospacedDigit())
                                Text("密钥").font(.caption2)
                            }
                            .foregroundStyle(Color.dsAccentPurple)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            } header: {
                Text("服务状态")
            }
        }
    }

    private var settingsSection: some View {
        Group {
            Section("基本设置") {
                Toggle("启用推送", isOn: $pushEnabled)
                    .listRowBackground(Color.clear)
                Picker("默认推送密钥", selection: $defaultPushKeyId) {
                    Text("未设置").tag("")
                    ForEach(vm.pushKeys) { key in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.displayName)
                                .lineLimit(1)
                            if let kid = key.key_id, !kid.isEmpty {
                                Text("Key: \(kid)" + (key.team_id.map { " · Team: \($0)" } ?? ""))
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsMuted)
                                    .lineLimit(1)
                            }
                        }
                        .tag(key.id)
                    }
                }
                .listRowBackground(Color.clear)
                TextField("默认 Bundle ID", text: $defaultBundleId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .listRowBackground(Color.clear)
                Toggle("默认沙盒模式", isOn: $defaultSandbox)
                    .listRowBackground(Color.clear)
            }

            Section("高级设置") {
                HStack {
                    Text("最大并发数")
                    Spacer()
                    TextField("10", text: $maxConcurrency)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                .listRowBackground(Color.clear)
                Toggle("自动清理无效设备", isOn: $autoCleanup)
                    .listRowBackground(Color.clear)
                HStack {
                    Text("历史保留天数")
                    Spacer()
                    TextField("30", text: $historyRetentionDays)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("TF 分发自动推送", isOn: $tfAutoPushEnabled)
                    .listRowBackground(Color.clear)
                if tfAutoPushEnabled {
                    Picker("API 账号", selection: $selectedAccountIdForTF) {
                        Text("选择账号").tag("")
                        ForEach(vm.accounts) { acc in
                            Text(acc.displayName).tag(acc.id)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .onChange(of: selectedAccountIdForTF) { _, newId in
                        if !newId.isEmpty {
                            Task { await vm.loadTestGroups(accountId: newId) }
                        }
                    }

                    if selectedAccountIdForTF.isEmpty {
                        HStack(spacing: 6) {
                            HIcon(AppIcon.info)
                                .font(.caption2)
                                .foregroundStyle(Color.dsMuted)
                            Text("请先选择 API 账号以加载测试组")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }
                        .listRowBackground(Color.clear)
                    } else if vm.isLoadingTestGroups {
                        HStack(spacing: 8) {
                            ProgressView().tint(Color.dsAccentBlue)
                            Text("加载测试组...")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        Picker("目标测试组", selection: $tfAutoPushGroupId) {
                            Text("不限定（全部）").tag("")
                            ForEach(vm.testGroups) { group in
                                Text(group.groupLabel).tag(group.id)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .onChange(of: tfAutoPushGroupId) { _, newId in
                            if let group = vm.testGroups.first(where: { $0.id == newId }),
                               let bid = group.bundle_id, !bid.isEmpty {
                                tfAutoPushBundleId = bid
                            }
                        }

                        if let group = vm.testGroups.first(where: { $0.id == tfAutoPushGroupId }),
                           let bid = group.bundle_id, !bid.isEmpty {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.info)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsAccentBlue)
                                Text("Bundle ID 已自动填充：\(bid)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsAccentBlue)
                                    .lineLimit(1)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("推送 Bundle ID")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                        TextField("留空使用默认 Bundle ID", text: $tfAutoPushBundleId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .listRowBackground(Color.clear)
                    TextField("推送标题", text: $tfAutoPushTitle)
                        .listRowBackground(Color.clear)
                    TextField("推送内容", text: $tfAutoPushBody, axis: .vertical)
                        .lineLimit(2...4)
                        .listRowBackground(Color.clear)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            HIcon(AppIcon.code)
                                .font(.caption)
                                .foregroundStyle(Color.dsAccentCyan)
                            Text("模板变量")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dsText)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            templateVar("{version}", "完整版本号 (v1.2.0 (36))")
                            templateVar("{v}", "版本号 (1.2.0)")
                            templateVar("{build}", "构建号 (36)")
                            templateVar("{whats_new}", "测试内容")
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("TestFlight 自动推送")
            } footer: {
                Text("开启后，每次分发新构建版本时自动推送通知。测试组 ID 可在 TestFlight 分组管理中查看，留空则不限定。推送 Bundle ID 留空使用上方默认 Bundle ID。")
                    .font(.caption)
            }
        }
    }

    private var saveSection: some View {
        Section {
            Button {
                Task { await save() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        HIcon(AppIcon.check).font(.body)
                    }
                    Text("保存设置")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .disabled(isSaving)

            if let msg = saveMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(msg.contains("成功") ? Color.dsAccent : Color.dsAccentPink)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func applySettings() {
        guard let s = vm.pushSettings else { return }
        pushEnabled = s.isEnabled
        defaultPushKeyId = s.default_push_key_id ?? ""
        defaultBundleId = s.default_bundle_id ?? ""
        defaultSandbox = s.default_sandbox == "true"
        maxConcurrency = s.max_concurrency ?? "10"
        autoCleanup = s.auto_cleanup_enabled == "true"
        historyRetentionDays = s.history_retention_days ?? "30"
        tfAutoPushEnabled = s.tf_auto_push_enabled == "true"
        tfAutoPushTitle = s.tf_auto_push_title ?? "新版本 {version}"
        tfAutoPushBody = s.tf_auto_push_body ?? "新版本已分发到测试组，请前往 TestFlight 更新。\n{whats_new}"
        tfAutoPushBundleId = s.tf_auto_push_bundle_id ?? ""

        let savedGroupId = s.tf_auto_push_group_id ?? ""
        if !savedGroupId.isEmpty, let firstAccount = vm.accounts.first {
            selectedAccountIdForTF = firstAccount.id
            Task {
                await vm.loadTestGroups(accountId: firstAccount.id)
                tfAutoPushGroupId = savedGroupId
            }
        } else {
            tfAutoPushGroupId = savedGroupId
        }
    }

    private func templateVar(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(Color.dsAccentCyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.dsAccentCyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            Text(desc)
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
    }

    private func save() async {
        isSaving = true
        saveMessage = nil
        let updates: [String: String] = [
            "push_enabled": pushEnabled ? "true" : "false",
            "default_push_key_id": defaultPushKeyId,
            "default_bundle_id": defaultBundleId,
            "default_sandbox": defaultSandbox ? "true" : "false",
            "max_concurrency": maxConcurrency,
            "auto_cleanup_enabled": autoCleanup ? "true" : "false",
            "history_retention_days": historyRetentionDays,
            "tf_auto_push_enabled": tfAutoPushEnabled ? "true" : "false",
            "tf_auto_push_title": tfAutoPushTitle,
            "tf_auto_push_body": tfAutoPushBody,
            "tf_auto_push_group_id": tfAutoPushGroupId,
            "tf_auto_push_bundle_id": tfAutoPushBundleId,
        ]
        do {
            try await vm.saveSettings(updates)
            saveMessage = "保存成功"
        } catch {
            saveMessage = "保存失败: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
