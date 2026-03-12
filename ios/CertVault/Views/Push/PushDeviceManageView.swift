import SwiftUI
import HiconIcons

struct PushDeviceManageView: View {
    @StateObject private var vm = PushViewModel()
    @State private var showAddSheet = false
    @State private var showCleanupAlert = false
    @State private var selectedIds = Set<Int>()
    @State private var isEditing = false
    @State private var cleanupResult: String?
    @State private var cleanupBundleId = ""
    @State private var editingDevice: PushDevice?
    @State private var batchActionResult: String?

    var body: some View {
        List(selection: isEditing ? $selectedIds : nil) {
            statsSection
            deviceListSection
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("设备管理")
        .refreshable { await reload() }
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showAddSheet = true } label: {
                        Label("添加设备", systemImage: "plus")
                    }
                    Button { isEditing.toggle() } label: {
                        Label(isEditing ? "完成" : "批量管理", systemImage: "checklist")
                    }
                    Button(role: .destructive) { showCleanupAlert = true } label: {
                        Label("清理无效设备", systemImage: "trash.slash")
                    }
                } label: {
                    HIcon(AppIcon.moreCircle)
                }
            }

            if isEditing && !selectedIds.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                Task { await batchSwitch(sandbox: false) }
                            } label: {
                                Label("切换到生产", systemImage: "bolt.shield")
                            }
                            Button {
                                Task { await batchSwitch(sandbox: true) }
                            } label: {
                                Label("切换到沙盒", systemImage: "testtube.2")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.swap)
                                    .font(.caption)
                                Text("切换环境 (\(selectedIds.count))")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(Color.dsAccentBlue)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            Task {
                                try? await vm.batchDeleteDevices(ids: Array(selectedIds))
                                selectedIds.removeAll()
                                isEditing = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.trash)
                                    .font(.caption)
                                Text("删除 (\(selectedIds.count))")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(Color.dsAccentPink)
                        }
                    }
                }
            }
        }
        .glassSheet(isPresented: $showAddSheet) {
            AddDeviceSheet(vm: vm) { showAddSheet = false }
        }
        .glassSheet(item: $editingDevice) { device in
            EditDeviceSheet(vm: vm, device: device) { editingDevice = nil }
        }
        .alert("清理无效设备", isPresented: $showCleanupAlert) {
            TextField("Bundle ID", text: $cleanupBundleId)
            Button("清理") {
                guard !cleanupBundleId.isEmpty else { return }
                Task {
                    do {
                        let r = try await vm.cleanupDevices(bundleId: cleanupBundleId, pushKeyId: nil)
                        cleanupResult = "清理完成：\(r.valid) 有效，\(r.removed) 已移除，\(r.errored) 出错"
                    } catch {
                        cleanupResult = "清理失败: \(error.localizedDescription)"
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将验证所有设备 Token 的有效性，移除已失效的设备。请输入 Bundle ID。")
        }
        .task { await reload() }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats = vm.deviceStats {
            Section("设备统计") {
                HStack(spacing: 0) {
                    statCell("总计", value: stats.total?.value ?? 0, color: .dsAccentBlue)
                    Divider().frame(height: 40)
                    statCell("沙盒", value: stats.sandbox?.value ?? 0, color: .dsAccentOrange)
                    Divider().frame(height: 40)
                    statCell("生产", value: stats.production?.value ?? 0, color: .dsAccent)
                    Divider().frame(height: 40)
                    statCell("iOS", value: stats.ios?.value ?? 0, color: .dsAccentPurple)
                }
                    .listRowBackground(Color.clear)

                if let msg = cleanupResult {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("完成") ? Color.dsAccent : Color.dsAccentPink)
                        .listRowBackground(Color.clear)
                }
                if let msg = batchActionResult {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("成功") ? Color.dsAccent : Color.dsAccentPink)
                        .listRowBackground(Color.clear)
                }
            }
        }
    }

    private var deviceListSection: some View {
        Section("设备列表 (\(vm.devices.count))") {
            if vm.isLoading && vm.devices.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if vm.devices.isEmpty {
                VStack(spacing: 12) {
                    HIcon(AppIcon.iphoneSlash)
                        .font(.system(size: 36))
                        .foregroundStyle(Color.dsMuted)
                    Text("暂无设备")
                        .font(.headline)
                        .foregroundStyle(Color.dsText)
                    Text("注册或手动添加设备 Token")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .listRowBackground(Color.clear)
            } else {
                ForEach(vm.devices, id: \.stableId) { device in
                    Button {
                        editingDevice = device
                    } label: {
                        deviceRow(device)
                    }
                    .tint(Color.dsText)
                    .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    Task {
                        for idx in offsets {
                            if let id = vm.devices[idx].id {
                                try? await vm.deleteDevice(id: id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: PushDevice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(device.displayToken)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(device.envLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent, in: RoundedRectangle(cornerRadius: 4))
            }

            if let label = device.label, !label.isEmpty {
                HStack(spacing: 4) {
                    HIcon(AppIcon.tag)
                        .font(.system(size: 9))
                    Text(label)
                }
                .font(.caption)
                .foregroundStyle(Color.dsAccentPurple)
            }

            HStack(spacing: 10) {
                if let user = device.username, !user.isEmpty {
                    HStack(spacing: 3) {
                        HIcon(AppIcon.person)
                            .font(.system(size: 9))
                        Text(user)
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.dsAccentBlue)
                }

                if let platform = device.platform {
                    Text(platform.uppercased())
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }

                Spacer()

                if let date = device.created_at {
                    Text(String(date.prefix(19)))
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func statCell(_ label: String, value: Int, color: Color) -> some View {
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

    private func reload() async {
        async let d: () = vm.loadDevices()
        async let s: () = vm.loadDeviceStats()
        _ = await (d, s)
    }

    private func batchSwitch(sandbox: Bool) async {
        batchActionResult = nil
        do {
            let count = try await vm.batchUpdateDevices(ids: Array(selectedIds), sandbox: sandbox)
            batchActionResult = "成功切换 \(count) 个设备到\(sandbox ? "沙盒" : "生产")环境"
            selectedIds.removeAll()
            isEditing = false
            await vm.loadDeviceStats()
        } catch {
            batchActionResult = "切换失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Add Device Sheet

private struct AddDeviceSheet: View {
    @ObservedObject var vm: PushViewModel
    let onDismiss: () -> Void

    @State private var token = ""
    @State private var platform = "ios"
    @State private var sandbox = false
    @State private var label = ""
    @State private var isAdding = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("设备信息") {
                    TextField("Device Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                    Picker("平台", selection: $platform) {
                        Text("iOS").tag("ios")
                        Text("macOS").tag("macos")
                    }
                    Toggle("沙盒环境", isOn: $sandbox)
                    TextField("标签（可选）", text: $label)
                }

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsAccentPink)
                    }
                }

                Section {
                    Button {
                        Task { await add() }
                    } label: {
                        HStack {
                            if isAdding { ProgressView().tint(.white) }
                            Text("添加设备")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(token.isEmpty ? Color.dsMuted : .white)
                        .background(token.isEmpty ? Color.dsSurfaceLight : Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .listRowInsets(EdgeInsets())
                    .disabled(token.isEmpty || isAdding)
                }
            }
            .navigationTitle("添加设备")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                }
            }
        }
        .sheetStyle()
    }

    private func add() async {
        isAdding = true
        errorMsg = nil
        do {
            try await vm.addDevice(token: token, platform: platform, sandbox: sandbox, label: label.isEmpty ? nil : label)
            onDismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isAdding = false
    }
}

// MARK: - Edit Device Sheet

private struct EditDeviceSheet: View {
    @ObservedObject var vm: PushViewModel
    let device: PushDevice
    let onDismiss: () -> Void

    @State private var label: String = ""
    @State private var sandbox: Bool = false
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showDeleteAlert = false
    @State private var copiedToken = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        HIcon(AppIcon.iphone)
                            .font(.system(size: 32))
                            .foregroundStyle(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent)
                            .frame(width: 60, height: 60)
                            .background((device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent).opacity(0.12), in: Circle())

                        if let lbl = device.label, !lbl.isEmpty {
                            Text(lbl)
                                .font(.headline)
                                .foregroundStyle(Color.dsText)
                        }

                        Text(device.envLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent, in: Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Device Token") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(device.device_token ?? "-")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.dsText)
                            .textSelection(.enabled)

                        Button {
                            UIPasteboard.general.string = device.device_token
                            withAnimation { copiedToken = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copiedToken = false }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if copiedToken {
                                    HIcon(AppIcon.check)
                                } else {
                                    HIcon(AppIcon.docCopy)
                                }
                                Text(copiedToken ? "已复制" : "复制 Token")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(copiedToken ? Color.dsAccent : Color.dsAccentBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("设备详情") {
                    LabeledContent("ID") {
                        Text("\(device.id ?? 0)")
                            .font(.subheadline.monospaced())
                            .foregroundStyle(Color.dsMuted)
                    }
                    LabeledContent("平台") {
                        Text((device.platform ?? "ios").uppercased())
                            .font(.subheadline.weight(.medium))
                    }
                    LabeledContent("环境") {
                        Text(device.envLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent)
                    }
                    if let user = device.username, !user.isEmpty {
                        LabeledContent("注册用户") {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.person)
                                    .font(.caption2)
                                Text(user)
                            }
                            .foregroundStyle(Color.dsAccentBlue)
                            .font(.subheadline)
                        }
                    }
                    if let date = device.created_at {
                        LabeledContent("注册时间") {
                            Text(String(date.prefix(19)))
                                .font(.subheadline)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                }

                Section("编辑") {
                    TextField("标签", text: $label)
                    Toggle("沙盒环境", isOn: $sandbox)
                }

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsAccentPink)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text("保存修改")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .listRowInsets(EdgeInsets())
                    .disabled(isSaving)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            HIcon(AppIcon.trash)
                            Text("删除此设备")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("设备详情")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onDismiss() }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("删除", role: .destructive) {
                    Task {
                        if let id = device.id {
                            try? await vm.deleteDevice(id: id)
                        }
                        onDismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复，确定要删除此设备吗？")
            }
            .onAppear {
                label = device.label ?? ""
                sandbox = device.sandbox ?? false
            }
        }
        .sheetStyle()
    }

    private func save() async {
        guard let id = device.id else { return }
        isSaving = true
        errorMsg = nil
        do {
            try await vm.updateDevice(id: id, label: label.isEmpty ? nil : label, sandbox: sandbox)
            onDismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }
}
