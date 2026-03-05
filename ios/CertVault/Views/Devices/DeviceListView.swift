import SwiftUI
import HiconIcons

struct DeviceListView: View {
    @StateObject private var vm = DeviceViewModel()
    @State private var showRegister = false
    @State private var showBatchImport = false
    @State private var showAutoBind = false
    @State private var searchText = ""
    @State private var showDisabled = true
    @State private var showIneligible = true

    private var filteredDevices: [Device] {
        if searchText.isEmpty { return vm.devices }
        return vm.devices.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.udid ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var enabledDevices: [Device] { filteredDevices.filter { $0.isEnabled } }
    private var disabledDevices: [Device] { filteredDevices.filter { $0.isDisabled } }
    private var ineligibleDevices: [Device] { filteredDevices.filter { $0.isIneligible } }

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                DSEmptyState(
                    icon: AppIcon.account,
                    title: L10n.Device.noAccountTitle,
                    message: L10n.Device.noAccountMessage
                )
            } else if vm.devices.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                DSEmptyState(
                    icon: AppIcon.device,
                    title: L10n.Device.emptyTitle,
                    message: L10n.Device.emptyMessage,
                    actionTitle: L10n.Device.emptyAction
                ) { showRegister = true }
            } else {
                ScrollView {
                    VStack(spacing: DS.spacingLG) {
                        if vm.accounts.count > 1 {
                            accountPicker
                                .padding(.horizontal, DS.spacingLG)
                        }

                        if !enabledDevices.isEmpty {
                            deviceSection(
                                title: L10n.Device.enabledSection,
                                count: enabledDevices.count,
                                color: .dsGreen,
                                devices: enabledDevices
                            )
                        }

                        if !disabledDevices.isEmpty {
                            collapsibleSection(
                                title: L10n.Device.disabledSection,
                                count: disabledDevices.count,
                                color: .dsPink,
                                devices: disabledDevices,
                                isExpanded: $showDisabled
                            )
                        }

                        if !ineligibleDevices.isEmpty {
                            collapsibleSection(
                                title: L10n.Device.ineligibleSection,
                                count: ineligibleDevices.count,
                                color: .dsOrange,
                                devices: ineligibleDevices,
                                isExpanded: $showIneligible
                            )
                        }
                    }
                    .padding(.top, DS.spacingSM)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .searchable(text: $searchText, prompt: L10n.Device.search)
                .refreshable { await vm.loadDevices() }
            }
        }
        .navigationTitle(L10n.Device.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showRegister = true } label: {
                        Label { Text(L10n.Device.register) } icon: { HIcon(AppIcon.addSquare) }
                    }
                    Button { showBatchImport = true } label: {
                        Label { Text(L10n.Device.batchImport) } icon: { HIcon(AppIcon.copy) }
                    }
                    Divider()
                    Button { showAutoBind = true } label: {
                        Label { Text(L10n.Device.autoBind) } icon: { HIcon(AppIcon.link) }
                    }
                } label: {
                    HIcon(AppIcon.addCircle)
                }
                .buttonStyle(.dsPressed)
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

    private func collapsibleSection(title: String, count: Int, color: Color, devices: [Device], isExpanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: DS.spacingSM) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsText)
                    DSBadge(text: "\(count)", color: color)
                    Spacer()
                    HIcon(AppIcon.chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dsTextSecondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? -90 : 90))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.spacingXL)

            if isExpanded.wrappedValue {
                deviceGroupView(devices: devices)
            }
        }
    }

    private func deviceSection(title: String, count: Int, color: Color, devices: [Device]) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            HStack(spacing: DS.spacingSM) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dsText)
                DSBadge(text: "\(count)", color: color)
            }
            .padding(.horizontal, DS.spacingXL)

            deviceGroupView(devices: devices)
        }
    }

    private func deviceGroupView(devices: [Device]) -> some View {
        DSGroupedCard {
            ForEach(devices) { device in
                NavigationLink {
                    DeviceDetailView(deviceId: device.id, accountId: vm.selectedAccountId)
                } label: {
                    DeviceRow(device: device)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if device.isEnabled {
                        Button(role: .destructive) {
                            Task { try? await vm.toggleDeviceStatus(deviceId: device.id, enable: false) }
                        } label: {
                            Label { Text(L10n.Device.disabledSection) } icon: { HIcon(AppIcon.close) }
                        }
                    } else {
                        Button {
                            Task { try? await vm.toggleDeviceStatus(deviceId: device.id, enable: true) }
                        } label: {
                            Label { Text(L10n.Device.enabledSection) } icon: { HIcon(AppIcon.tick) }
                        }
                    }
                }

                if device.id != devices.last?.id {
                    DSDivider(leadingPadding: 56)
                }
            }
        }
        .padding(.horizontal, DS.spacingLG)
    }

    private var accountPicker: some View {
        HStack {
            Text(L10n.account)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            Picker("", selection: $vm.selectedAccountId) {
                ForEach(vm.accounts) { acc in
                    Text(acc.displayName).tag(acc.id)
                }
            }
            .tint(Color.dsBrand)
            .onChange(of: vm.selectedAccountId) { _ in
                Task { await vm.loadDevices() }
            }
        }
        .padding(DS.spacingLG)
        .cardStyle()
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: Device

    private var tintColor: Color {
        if device.isEnabled { return .dsGreen }
        if device.isIneligible { return .dsOrange }
        return .dsPink
    }

    var body: some View {
        DSRow(
            icon: iconForDevice,
            iconColor: tintColor,
            title: device.displayName,
            subtitle: device.udid ?? "N/A",
            trailing: AnyView(DSBadge.forStatus(device.status ?? "UNKNOWN")),
            showChevron: true
        )
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
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    if vm.accounts.count > 1 {
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            Text(L10n.account)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dsTextSecondary)
                            Picker(L10n.select, selection: $vm.selectedAccountId) {
                                ForEach(vm.accounts) { acc in
                                    Text(acc.displayName).tag(acc.id)
                                }
                            }
                            .tint(Color.dsBrand)
                        }
                        .padding(DS.spacingLG)
                        .cardStyle()
                    }

                    VStack(spacing: DS.spacingMD) {
                        DSInputFieldBuilder(icon: AppIcon.device, focused: false) {
                            TextField("", text: $name, prompt: Text(L10n.Device.formName).foregroundColor(.dsTextTertiary))
                                .foregroundStyle(Color.dsText)
                        }

                        DSInputFieldBuilder(icon: AppIcon.udid, focused: false) {
                            TextField("", text: $udid, prompt: Text(L10n.Device.formUdid).foregroundColor(.dsTextTertiary))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color.dsText)
                        }

                        DSInputFieldBuilder(icon: AppIcon.device, focused: false) {
                            Picker(L10n.Device.formPlatform, selection: $platform) {
                                ForEach(platforms, id: \.self) { Text($0) }
                            }
                            .foregroundStyle(Color.dsText)
                        }
                    }

                    if let err = errorMsg {
                        HStack(spacing: DS.spacingSM) {
                            HIcon(AppIcon.warning).font(.caption)
                            Text(err).font(.caption)
                        }
                        .foregroundStyle(Color.dsDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.spacingXS)
                    }

                    DSPrimaryButton(
                        title: L10n.Device.register,
                        isLoading: isLoading,
                        isDisabled: name.isEmpty || udid.isEmpty
                    ) {
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
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingXL)
            }
            .background(Color.dsBackground)
            .navigationTitle(L10n.Device.register)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundStyle(Color.dsBrand)
                }
            }
        }
    }
}
