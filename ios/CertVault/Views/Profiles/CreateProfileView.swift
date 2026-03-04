import SwiftUI
import HiconIcons

struct CreateProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedType = "IOS_APP_DEVELOPMENT"
    @State private var selectedBundleId = ""
    @State private var selectedCertIds: Set<String> = []
    @State private var selectedDeviceIds: Set<String> = []
    @State private var isLoading = false
    @State private var errorMsg: String?

    var needsDevices: Bool {
        ["IOS_APP_DEVELOPMENT", "IOS_APP_ADHOC"].contains(selectedType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("描述文件名称", text: $name)
                    Picker("类型", selection: $selectedType) {
                        ForEach(vm.profileTypes) { type in
                            Text(type.label).tag(type.value)
                        }
                    }
                }

                Section("Bundle ID") {
                    if vm.bundleIds.isEmpty {
                        Text("暂无 Bundle ID，请先创建")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("选择 Bundle ID", selection: $selectedBundleId) {
                            Text("请选择").tag("")
                            ForEach(vm.bundleIds) { bid in
                                Text("\(bid.displayName) (\(bid.identifier ?? ""))").tag(bid.id)
                            }
                        }
                    }
                }

                Section("证书") {
                    if vm.certificates.isEmpty {
                        Text("加载中...")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.certificates) { cert in
                            HStack {
                                Text(cert.displayName)
                                    .font(.subheadline)
                                Spacer()
                                if selectedCertIds.contains(cert.id) {
                                    HIcon(AppIcon.check)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedCertIds.contains(cert.id) {
                                    selectedCertIds.remove(cert.id)
                                } else {
                                    selectedCertIds.insert(cert.id)
                                }
                            }
                        }
                    }
                }

                if needsDevices {
                    Section("设备") {
                        if vm.devices.isEmpty {
                            Text("加载中...")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("全选") {
                                selectedDeviceIds = Set(vm.devices.map(\.id))
                            }
                            .font(.caption)

                            ForEach(vm.devices) { device in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.displayName)
                                            .font(.subheadline)
                                        Text(device.udid ?? "")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedDeviceIds.contains(device.id) {
                                        HIcon(AppIcon.check)
                                            .foregroundStyle(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedDeviceIds.contains(device.id) {
                                        selectedDeviceIds.remove(device.id)
                                    } else {
                                        selectedDeviceIds.insert(device.id)
                                    }
                                }
                            }
                        }
                    }
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("创建描述文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create() }
                        .disabled(!isValid || isLoading)
                }
            }
            .task {
                if vm.accounts.isEmpty {
                    await vm.loadAccounts()
                }
                if vm.bundleIds.isEmpty {
                    await vm.loadBundleIds()
                }
                await vm.loadProfileDeps()
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !selectedBundleId.isEmpty && !selectedCertIds.isEmpty
            && (!needsDevices || !selectedDeviceIds.isEmpty)
    }

    private func create() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await vm.createProfile(
                    name: name, type: selectedType,
                    bundleId: selectedBundleId,
                    certIds: Array(selectedCertIds),
                    deviceIds: needsDevices ? Array(selectedDeviceIds) : []
                )
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
