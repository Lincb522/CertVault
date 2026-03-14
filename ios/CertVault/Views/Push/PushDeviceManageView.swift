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
    @State private var showHistory = false
    @State private var showValidateResult = false
    @State private var showValidateAllResult = false
    @State private var validatingDeviceId: Int?

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
                    Button { showHistory = true } label: {
                        Label("上报历史", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        Task {
                            await vm.validateAllDevices()
                            showValidateAllResult = true
                        }
                    } label: {
                        Label("检测所有设备", systemImage: "checkmark.shield")
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
        .glassSheet(isPresented: $showHistory) {
            DeviceRegisterHistoryView(vm: vm)
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
        .glassSheet(isPresented: $showValidateResult) {
            DeviceValidateResultSheet(result: vm.validateResult, isLoading: vm.isValidating) {
                showValidateResult = false
            }
        }
        .glassSheet(isPresented: $showValidateAllResult) {
            DeviceValidateAllResultSheet(result: vm.validateAllResult, isLoading: vm.isValidatingAll) {
                showValidateAllResult = false
                Task { await reload() }
            }
        }
        .task { await reload() }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats = vm.deviceStats {
            Section {
                InlineStatGrid(items: [
                    ("总计", stats.total?.value ?? 0, .dsAccentBlue),
                    ("沙盒", stats.sandbox?.value ?? 0, .dsAccentOrange),
                    ("生产", stats.production?.value ?? 0, .dsAccent),
                    ("iOS", stats.ios?.value ?? 0, .dsAccentPurple),
                ])
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

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
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            if let id = device.id {
                                validatingDeviceId = id
                                Task {
                                    await vm.validateDevice(id: id)
                                    showValidateResult = true
                                }
                            }
                        } label: {
                            Label("检测", systemImage: "checkmark.shield")
                        }
                        .tint(.dsAccentBlue)
                    }
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
        let title: String = {
            if let rk = device.remark, !rk.isEmpty { return rk }
            if let name = device.device_name, !name.isEmpty { return name }
            return "未知设备"
        }()

        return HStack(spacing: 12) {
            HIcon(AppIcon.iphone)
                .font(.system(size: 16))
                .foregroundStyle(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent)
                .frame(width: 36, height: 36)
                .background((device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
                        .lineLimit(1)
                    Spacer()
                    Text(device.envLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent, in: RoundedRectangle(cornerRadius: 4))
                }

                HStack(spacing: 6) {
                    if let model = device.model, !model.isEmpty {
                        Text(model)
                            .foregroundStyle(Color.dsAccentPurple)
                    }
                    if let os = device.os_version, !os.isEmpty {
                        Text(os)
                            .foregroundStyle(Color.dsAccentBlue)
                    }
                    if let ver = device.app_version, !ver.isEmpty {
                        Text("v\(ver)")
                            .foregroundStyle(Color.dsAccentOrange)
                    }
                }
                .font(.caption)
                .lineLimit(1)

                if device.model == nil || device.model?.isEmpty == true,
                   let label = device.label, !label.isEmpty {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(Color.dsAccentPurple)
                        .lineLimit(1)
                }

                HStack {
                    Text(device.displayToken)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(1)

                    Spacer()

                    if let date = device.created_at {
                        Text(formatShortDate(date))
                            .font(.caption2)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatShortDate(_ dateStr: String) -> String {
        dateStr.toLocalDate()
    }

    // Stats rendered via InlineStatGrid

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
    @State private var remark = ""
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
                    TextField("备注（可选）", text: $remark, axis: .vertical)
                        .lineLimit(2...4)
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
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
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
            try await vm.addDevice(token: token, platform: platform, sandbox: sandbox, label: label.isEmpty ? nil : label, remark: remark.isEmpty ? nil : remark)
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
    @State private var remark: String = ""
    @State private var sandbox: Bool = false
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showDeleteAlert = false
    @State private var copiedToken = false
    @State private var showValidateResult = false

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

                        Text({
                            if let rk = device.remark, !rk.isEmpty { return rk }
                            if let name = device.device_name, !name.isEmpty { return name }
                            return "未知设备"
                        }() as String)
                            .font(.headline)
                            .foregroundStyle(Color.dsText)

                        if let model = device.model, !model.isEmpty {
                            Text(model)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccentPurple)
                        }

                        HStack(spacing: 8) {
                            Text(device.envLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(device.sandbox == true ? Color.dsAccentOrange : Color.dsAccent, in: Capsule())

                            if let os = device.os_version, !os.isEmpty {
                                Text(os)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.dsAccentBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.dsAccentBlue.opacity(0.12), in: Capsule())
                            }
                            if let ver = device.app_version, !ver.isEmpty {
                                Text("v\(ver)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.dsAccentOrange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.dsAccentOrange.opacity(0.12), in: Capsule())
                            }
                        }
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
                    if let name = device.device_name, !name.isEmpty {
                        LabeledContent("设备名称") {
                            Text(name)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    if let model = device.model, !model.isEmpty {
                        LabeledContent("机型") {
                            Text(model)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsAccentPurple)
                        }
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
                    if let os = device.os_version, !os.isEmpty {
                        LabeledContent("系统版本") {
                            Text(os)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsAccentBlue)
                        }
                    }
                    if let ver = device.app_version, !ver.isEmpty {
                        LabeledContent("App 版本") {
                            Text("v\(ver)")
                                .font(.subheadline.monospaced())
                                .foregroundStyle(Color.dsAccentOrange)
                        }
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
                            Text(date.toLocalDate())
                                .font(.subheadline)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    if let rk = device.remark, !rk.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("备注")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                            Text(rk)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsText)
                        }
                    }
                }

                Section("编辑") {
                    TextField("标签", text: $label)
                    TextField("备注", text: $remark, axis: .vertical)
                        .lineLimit(2...6)
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
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .disabled(isSaving)
                }

                Section {
                    Button {
                        if let id = device.id {
                            Task {
                                await vm.validateDevice(id: id)
                                showValidateResult = true
                            }
                        }
                    } label: {
                        HStack {
                            if vm.isValidating {
                                ProgressView()
                                    .tint(Color.dsAccentBlue)
                            } else {
                                Image(systemName: "checkmark.shield")
                            }
                            Text(vm.isValidating ? "检测中..." : "检测 Token 有效性")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.dsAccentBlue)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isValidating)
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
                remark = device.remark ?? ""
                sandbox = device.sandbox ?? false
            }
            .glassSheet(isPresented: $showValidateResult) {
                DeviceValidateResultSheet(result: vm.validateResult, isLoading: vm.isValidating) {
                    showValidateResult = false
                }
            }
        }
        .sheetStyle()
    }

    private func save() async {
        guard let id = device.id else { return }
        isSaving = true
        errorMsg = nil
        do {
            try await vm.updateDevice(id: id, label: label.isEmpty ? nil : label, sandbox: sandbox, remark: remark.isEmpty ? nil : remark)
            onDismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Device Register History View

struct DeviceRegisterHistoryView: View {
    @ObservedObject var vm: PushViewModel
    @State private var filterAction = "all"
    @State private var selectedItem: DeviceRegisterHistory?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("筛选", selection: $filterAction) {
                        Text("全部").tag("all")
                        Text("注册").tag("register")
                        Text("上报").tag("report")
                        Text("失效").tag("invalidated")
                        Text("注销").tag("unregister")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .onChange(of: filterAction) { _ in
                        Task { await loadHistory() }
                    }
                }

                Section("记录 (\(vm.deviceHistoryTotal))") {
                    if vm.isLoading && vm.deviceHistory.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    } else if vm.deviceHistory.isEmpty {
                        VStack(spacing: 10) {
                            HIcon(AppIcon.clock)
                                .font(.system(size: 32))
                                .foregroundStyle(Color.dsMuted)
                            Text("暂无记录")
                                .font(.headline)
                                .foregroundStyle(Color.dsText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(vm.deviceHistory, id: \.stableId) { item in
                            Button { selectedItem = item } label: {
                                historyRow(item)
                            }
                            .tint(Color.dsText)
                            .listRowBackground(Color.clear)
                        }

                        if vm.deviceHistory.count < vm.deviceHistoryTotal {
                            Button {
                                Task { await vm.loadMoreDeviceHistory(action: filterAction == "all" ? nil : filterAction) }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("加载更多")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.dsAccentBlue)
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle("上报历史")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await loadHistory() }
            .refreshable { await loadHistory() }
            .overlay {
                if let msg = vm.errorMessage, vm.deviceHistory.isEmpty, !vm.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(Color.dsAccentOrange)
                        Text("加载失败")
                            .font(.headline)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .glassSheet(item: $selectedItem) { item in
                DeviceHistoryDetailSheet(vm: vm, item: item)
            }
        }
        .sheetStyle()
    }

    private func loadHistory() async {
        await vm.loadDeviceHistory(action: filterAction == "all" ? nil : filterAction)
    }

    private func historyRow(_ item: DeviceRegisterHistory) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                Spacer()
                Text(item.actionLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(actionColor(item.action), in: RoundedRectangle(cornerRadius: 4))
            }

            HStack(spacing: 8) {
                if let model = item.model, !model.isEmpty {
                    HStack(spacing: 3) {
                        HIcon(AppIcon.iphone)
                            .font(.system(size: 9))
                        Text(model)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.dsAccentPurple)
                }
                if let os = item.os_version, !os.isEmpty {
                    Text(os)
                        .font(.caption)
                        .foregroundStyle(Color.dsAccentBlue)
                }
                if let ver = item.app_version, !ver.isEmpty {
                    Text("v\(ver)")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.dsAccentOrange)
                }
            }

            HStack(spacing: 10) {
                if let user = item.username, !user.isEmpty {
                    HStack(spacing: 3) {
                        HIcon(AppIcon.person)
                            .font(.system(size: 9))
                        Text(user)
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.dsAccentBlue)
                }

                Text(item.displayToken)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.dsMuted)

                Spacer()

                if let date = item.created_at {
                    Text(date.toLocalDate())
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func actionColor(_ action: String?) -> Color {
        switch action {
        case "register": return .dsAccent
        case "report": return .dsAccentBlue
        case "invalidated": return .dsAccentOrange
        case "unregister": return .dsAccentPink
        default: return .dsMuted
        }
    }
}

// MARK: - Device History Detail Sheet

private struct DeviceHistoryDetailSheet: View {
    @ObservedObject var vm: PushViewModel
    let item: DeviceRegisterHistory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        HIcon(AppIcon.iphone)
                            .font(.system(size: 32))
                            .foregroundStyle(actionColor(item.action))
                            .frame(width: 60, height: 60)
                            .background(actionColor(item.action).opacity(0.12), in: Circle())

                        Text(item.displayTitle)
                            .font(.headline)
                            .foregroundStyle(Color.dsText)

                        if let model = item.model, !model.isEmpty {
                            Text(model)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsAccentPurple)
                        }

                        HStack(spacing: 8) {
                            Text(item.actionLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(actionColor(item.action), in: Capsule())

                            if item.sandbox == true {
                                Text("Sandbox")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.dsAccentOrange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.dsAccentOrange.opacity(0.12), in: Capsule())
                            }

                            if let os = item.os_version, !os.isEmpty {
                                Text(os)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.dsAccentBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.dsAccentBlue.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("详细信息") {
                    if let name = item.device_name, !name.isEmpty {
                        LabeledContent("设备名称") {
                            Text(name).font(.subheadline.weight(.medium))
                        }
                    }
                    if let model = item.model, !model.isEmpty {
                        LabeledContent("设备机型") {
                            Text(model).font(.subheadline.weight(.medium)).foregroundStyle(Color.dsAccentPurple)
                        }
                    }
                    if let os = item.os_version, !os.isEmpty {
                        LabeledContent("系统版本") {
                            Text(os).font(.subheadline.weight(.medium)).foregroundStyle(Color.dsAccentBlue)
                        }
                    }
                    if let ver = item.app_version, !ver.isEmpty {
                        LabeledContent("App 版本") {
                            Text("v\(ver)").font(.subheadline.monospaced()).foregroundStyle(Color.dsAccentOrange)
                        }
                    }
                    LabeledContent("平台") {
                        Text((item.platform ?? "ios").uppercased()).font(.subheadline.weight(.medium))
                    }
                    LabeledContent("环境") {
                        Text(item.sandbox == true ? "沙盒" : "生产")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(item.sandbox == true ? Color.dsAccentOrange : Color.dsAccent)
                    }
                    if let user = item.username, !user.isEmpty {
                        LabeledContent("操作用户") {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.person).font(.caption2)
                                Text(user)
                            }
                            .foregroundStyle(Color.dsAccentBlue)
                            .font(.subheadline)
                        }
                    }
                    if let rk = item.remark, !rk.isEmpty {
                        LabeledContent("备注") {
                            Text(rk).font(.subheadline).foregroundStyle(Color.dsText)
                        }
                    }
                    if let date = item.created_at {
                        LabeledContent("时间") {
                            Text(date.toLocalDate()).font(.subheadline).foregroundStyle(Color.dsMuted)
                        }
                    }
                }

                Section("Device Token") {
                    Text(item.device_token ?? "-")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.dsText)
                        .textSelection(.enabled)
                }

                if let label = item.label, !label.isEmpty {
                    Section("Label") {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
            }
            .navigationTitle("上报详情")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .sheetStyle()
    }

    private func actionColor(_ action: String?) -> Color {
        switch action {
        case "register": return .dsAccent
        case "report": return .dsAccentBlue
        case "invalidated": return .dsAccentOrange
        case "unregister": return .dsAccentPink
        default: return .dsMuted
        }
    }
}

// MARK: - Single Device Validate Result

private struct DeviceValidateResultSheet: View {
    let result: DeviceValidateResult?
    let isLoading: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("正在检测...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if let r = result {
                    Section {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(r.valid ? Color.dsAccent.opacity(0.15) : Color.dsAccentPink.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Image(systemName: r.valid ? "checkmark.shield.fill" : "xmark.shield.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(r.valid ? Color.dsAccent : Color.dsAccentPink)
                            }

                            Text(r.valid ? "Token 有效" : "Token 无效")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(r.valid ? Color.dsAccent : Color.dsAccentPink)

                            if let cn = r.reason_cn, !cn.isEmpty, !r.valid {
                                Text(cn)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                    }

                    Section("检测详情") {
                        LabeledContent("状态") {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(r.valid ? Color.dsAccent : Color.dsAccentPink)
                                    .frame(width: 8, height: 8)
                                Text(r.valid ? "有效" : "无效")
                                    .foregroundStyle(r.valid ? Color.dsAccent : Color.dsAccentPink)
                            }
                        }
                        if let status = r.status {
                            LabeledContent("HTTP 状态码", value: "\(status)")
                        }
                        if let reason = r.reason, !reason.isEmpty {
                            LabeledContent("错误标识", value: reason)
                        }
                        if let cn = r.reason_cn, !cn.isEmpty {
                            LabeledContent("说明", value: cn)
                        }
                    }

                    Section("设备信息") {
                        if let name = r.device_name, !name.isEmpty {
                            LabeledContent("设备名称", value: name)
                        }
                        if let model = r.model, !model.isEmpty {
                            LabeledContent("机型", value: model)
                        }
                        if let token = r.device_token, !token.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Device Token")
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
                                Text(token)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Color.dsText)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                } else {
                    Text("无检测结果")
                        .foregroundStyle(Color.dsMuted)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("设备检测")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onDismiss() }
                }
            }
        }
        .sheetStyle()
    }
}

// MARK: - Validate All Result

private struct DeviceValidateAllResultSheet: View {
    let result: DeviceValidateAllResult?
    let isLoading: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("正在检测所有设备...")
                                .font(.subheadline)
                                .foregroundStyle(Color.dsMuted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                } else if let r = result {
                    Section {
                        InlineStatGrid(items: [
                            ("总计", r.total?.value ?? 0, .dsAccentBlue),
                            ("有效", r.valid?.value ?? 0, .dsAccent),
                            ("无效", r.invalid?.value ?? 0, .dsAccentPink),
                        ])
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    if let items = r.results, !items.isEmpty {
                        let invalidItems = items.filter { !$0.valid }
                        let validItems = items.filter { $0.valid }

                        if !invalidItems.isEmpty {
                            Section("无效设备 (\(invalidItems.count))") {
                                ForEach(invalidItems) { item in
                                    validateItemRow(item)
                                }
                            }
                        }

                        if !validItems.isEmpty {
                            Section("有效设备 (\(validItems.count))") {
                                ForEach(validItems) { item in
                                    validateItemRow(item)
                                }
                            }
                        }
                    }
                } else {
                    Text("无检测结果")
                        .foregroundStyle(Color.dsMuted)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("全部检测")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onDismiss() }
                }
            }
        }
        .sheetStyle()
    }

    private func validateItemRow(_ item: DeviceValidateItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.valid ? Color.dsAccent.opacity(0.12) : Color.dsAccentPink.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: item.valid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(item.valid ? Color.dsAccent : Color.dsAccentPink)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.device_name ?? item.model ?? "未知设备")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let model = item.model, !model.isEmpty {
                        Text(model)
                            .font(.caption2)
                            .foregroundStyle(Color.dsAccentPurple)
                    }
                    Text(item.displayToken)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.dsMuted)
                }

                if !item.valid, let cn = item.reason_cn, !cn.isEmpty {
                    Text(cn)
                        .font(.caption2)
                        .foregroundStyle(Color.dsAccentPink)
                }
            }

            Spacer()

            if let sandbox = item.sandbox {
                Text(sandbox ? "沙盒" : "生产")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(sandbox ? Color.dsAccentOrange : Color.dsAccent, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 3)
        .listRowBackground(Color.clear)
    }
}
