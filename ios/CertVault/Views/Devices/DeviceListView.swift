import SwiftUI
import HiconIcons

struct DeviceListView: View {
    @StateObject private var vm = DeviceViewModel()
    @State private var showRegister = false
    @State private var showBatchImport = false
    @State private var showAutoBind = false
    @State private var searchText = ""

    var filteredDevices: [Device] {
        if searchText.isEmpty { return vm.devices }
        return vm.devices.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.udid ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                EmptyStateView(
                    icon: AppIcon.account,
                    title: "暂无开发者账号",
                    message: "请先在「账号」页面添加 Apple Developer API Key"
                )
            } else if vm.devices.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                EmptyStateView(
                    icon: AppIcon.device,
                    title: "暂无设备",
                    message: "注册测试设备开始使用",
                    actionTitle: "添加设备"
                ) { showRegister = true }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if vm.accounts.count > 1 {
                            accountPicker
                                .padding(.horizontal, 16)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredDevices.enumerated()), id: \.element.id) { index, device in
                                NavigationLink {
                                    DeviceDetailView(deviceId: device.id, accountId: vm.selectedAccountId)
                                } label: {
                                    DeviceRow(device: device)
                                }
                                .buttonStyle(.plain)

                                if index < filteredDevices.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.dsBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .pageBackground()
                .searchable(text: $searchText, prompt: "搜索设备名称或 UDID")
                .refreshable { await vm.loadDevices() }
            }
        }
        .navigationTitle("设备管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showRegister = true } label: {
                        Label { Text("注册设备") } icon: { HIcon(AppIcon.addSquare) }
                    }
                    Button { showBatchImport = true } label: {
                        Label { Text("批量导入") } icon: { HIcon(AppIcon.copy) }
                    }
                    Divider()
                    Button { showAutoBind = true } label: {
                        Label { Text("一键绑定") } icon: { HIcon(AppIcon.link) }
                    }
                } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.devices.isEmpty {
                LoadingView()
            }
        }
        .task {
            AppLogger.ui.info("🖼️ DeviceListView appeared")
            await vm.loadAccounts()
        }
        .sheet(isPresented: $showRegister) {
            RegisterDeviceSheet(vm: vm)
        }
        .sheet(isPresented: $showBatchImport) {
            BatchImportView(vm: vm)
        }
        .sheet(isPresented: $showAutoBind) {
            AutoBindView(vm: vm)
        }
    }

    private var accountPicker: some View {
        HStack {
            Text("账号")
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
            Spacer()
            Picker("", selection: $vm.selectedAccountId) {
                ForEach(vm.accounts) { acc in
                    Text(acc.displayName).tag(acc.id)
                }
            }
            .tint(Color.dsAccentBlue)
            .onChange(of: vm.selectedAccountId) { _ in
                Task { await vm.loadDevices() }
            }
        }
        .padding(14)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 14) {
            HIcon(iconForDevice)
                .font(.body)
                .foregroundStyle(Color.dsAccent)
                .frame(width: 40, height: 40)
                .background(Color.dsAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                Text(device.udid ?? "N/A")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.dsMuted)
                    .lineLimit(1)
            }

            Spacer()

            StatusBadge.forStatus(device.status ?? "UNKNOWN")

            HIcon(AppIcon.chevronRight)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dsMuted.opacity(0.4))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private var iconForDevice: UIImage {
        switch device.device_class?.uppercased() ?? "" {
        case "IPAD": return AppIcon.display
        case "APPLE_WATCH": return AppIcon.watch
        case "APPLE_TV": return AppIcon.tv
        case "MAC": return AppIcon.display
        default: return AppIcon.device
        }
    }
}

// MARK: - Register Device Sheet

struct RegisterDeviceSheet: View {
    @ObservedObject var vm: DeviceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var udid = ""
    @State private var platform = "IOS"
    @State private var isLoading = false
    @State private var errorMsg: String?

    let platforms = ["IOS", "MAC_OS"]

    var body: some View {
        NavigationStack {
            Form {
                if vm.accounts.count > 1 {
                    Section("账号") {
                        Picker("选择账号", selection: $vm.selectedAccountId) {
                            ForEach(vm.accounts) { acc in
                                Text(acc.displayName).tag(acc.id)
                            }
                        }
                    }
                }

                Section("设备信息") {
                    TextField("设备名称", text: $name)
                    TextField("UDID", text: $udid)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("平台", selection: $platform) {
                        ForEach(platforms, id: \.self) { Text($0) }
                    }
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("注册设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("注册") {
                        isLoading = true
                        errorMsg = nil
                        Task {
                            do {
                                try await vm.register(name: name, udid: udid, platform: platform)
                                dismiss()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                    .disabled(name.isEmpty || udid.isEmpty || isLoading)
                }
            }
        }
    }
}
