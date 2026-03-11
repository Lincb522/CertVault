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
    @State private var isSaving = false
    @State private var saveMessage: String?

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
            applySettings()
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let status = vm.pushStatus {
            Section("服务状态") {
                LabeledContent("推送服务") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(status.push_enabled == true ? Color.dsAccent : Color.dsAccentPink)
                            .frame(width: 8, height: 8)
                        Text(status.push_enabled == true ? "已启用" : "未启用")
                            .foregroundStyle(status.push_enabled == true ? Color.dsAccent : Color.dsAccentPink)
                    }
                }
                if let dc = status.device_count {
                    LabeledContent("注册设备", value: "\(dc) 台")
                }
                if let kc = status.key_count {
                    LabeledContent("推送密钥", value: "\(kc) 个")
                }
            }
        }
    }

    private var settingsSection: some View {
        Group {
            Section("基本设置") {
                Toggle("启用推送", isOn: $pushEnabled)

                Picker("默认推送密钥", selection: $defaultPushKeyId) {
                    Text("未设置").tag("")
                    ForEach(vm.pushKeys) { key in
                        Text(key.displayName).tag(key.id)
                    }
                }

                TextField("默认 Bundle ID", text: $defaultBundleId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("默认沙盒模式", isOn: $defaultSandbox)
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

                Toggle("自动清理无效设备", isOn: $autoCleanup)

                HStack {
                    Text("历史保留天数")
                    Spacer()
                    TextField("30", text: $historyRetentionDays)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
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
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .disabled(isSaving)

            if let msg = saveMessage {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(msg.contains("成功") ? Color.dsAccent : Color.dsAccentPink)
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
