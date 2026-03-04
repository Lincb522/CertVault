import SwiftUI
import HiconIcons

struct CapabilityView: View {
    @StateObject private var vm = CapabilityViewModel()
    @State private var showDisableAllConfirm = false

    var body: some View {
        List {
            pickerSection

            if !vm.selectedBundleId.isEmpty {
                enabledCountSection
                presetsSection
                capabilitiesSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("权限管理")
        .overlay {
            if vm.isLoading {
                LoadingView()
            }
        }
        .task {
            await vm.loadAccounts()
            await vm.loadAvailable()
        }
        .alert("确认关闭全部", isPresented: $showDisableAllConfirm) {
            Button("关闭全部", role: .destructive) {
                Task { await vm.disableAll() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将关闭该 Bundle ID 的所有已开启权限")
        }
        .alert("操作失败", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var pickerSection: some View {
        Section {
            if vm.accounts.count > 1 {
                Picker("选择账号", selection: $vm.selectedAccountId) {
                    ForEach(vm.accounts) { acc in
                        Text(acc.displayName).tag(acc.id)
                    }
                }
                .onChange(of: vm.selectedAccountId) { _ in
                    Task { await vm.loadBundleIds() }
                }
            }

            Picker("选择 Bundle ID", selection: $vm.selectedBundleId) {
                Text("请选择").tag("")
                ForEach(vm.bundleIds) { bid in
                    Text(bid.identifier ?? bid.displayName).tag(bid.id)
                }
            }
            .onChange(of: vm.selectedBundleId) { _ in
                Task { await vm.loadEnabled() }
            }
        }
    }

    private var enabledCountSection: some View {
        Section {
            HStack {
                Text("已开启权限")
                    .font(.subheadline)
                Spacer()
                let count = vm.enabledCapabilities.filter(\.isEnabled).count
                let total = vm.availableCapabilities.count
                Text("\(count) / \(total)")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(count > 0 ? Color.dsAccent : Color.dsMuted)
            }
        }
    }

    private var presetsSection: some View {
        Section("预设方案") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(vm.presets.keys.sorted()), id: \.self) { name in
                        Button {
                            if let types = vm.presets[name] {
                                Task { await vm.applyPreset(types) }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                HIcon(iconForPreset(name))
                                    .font(.title3)
                                Text(labelForPreset(name))
                                    .font(.caption2)
                            }
                            .frame(width: 70, height: 60)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showDisableAllConfirm = true
                    } label: {
                        VStack(spacing: 4) {
                            HIcon(AppIcon.close)
                                .font(.title3)
                                .foregroundStyle(.red)
                            Text("全部关闭")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        .frame(width: 70, height: 60)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    private var capabilitiesSection: some View {
        ForEach(groupedCategories, id: \.0) { category, capabilities in
            Section(category) {
                ForEach(capabilities) { cap in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cap.name)
                                .font(.subheadline)
                            if let desc = cap.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if vm.togglingTypes.contains(cap.type) {
                            ProgressView().controlSize(.small)
                        } else {
                            Toggle("", isOn: .init(
                                get: { vm.isEnabled(cap.type) },
                                set: { _ in Task { await vm.toggle(cap.type) } }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    private var groupedCategories: [(String, [AvailableCapability])] {
        let categoryOrder = ["common", "payment", "media", "device", "network", "security"]
        let categoryLabels: [String: String] = [
            "common": "常用权限",
            "payment": "支付",
            "media": "媒体与内容",
            "device": "设备与硬件",
            "network": "网络",
            "security": "安全与隐私",
        ]

        var grouped: [String: [AvailableCapability]] = [:]
        for cap in vm.availableCapabilities {
            let cat = cap.category ?? "other"
            grouped[cat, default: []].append(cap)
        }

        var result: [(String, [AvailableCapability])] = []
        for key in categoryOrder where grouped[key] != nil {
            let label = categoryLabels[key] ?? key
            result.append((label, grouped.removeValue(forKey: key)!))
        }
        for (key, caps) in grouped.sorted(by: { $0.key < $1.key }) {
            let label = categoryLabels[key] ?? key
            result.append((label, caps))
        }
        return result
    }

    private func iconForPreset(_ name: String) -> UIImage {
        switch name.lowercased() {
        case "basic": return AppIcon.star
        case "social": return AppIcon.group
        case "game": return AppIcon.game
        case "enterprise": return AppIcon.work
        default: return AppIcon.category
        }
    }

    private func labelForPreset(_ name: String) -> String {
        switch name.lowercased() {
        case "basic": return "基础"
        case "social": return "社交"
        case "game": return "游戏"
        case "enterprise": return "企业"
        default: return name
        }
    }
}
