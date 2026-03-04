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
                Section(L10n.Account.formSectionBasic) {
                    TextField(NSLocalizedString("profile.title", comment: ""), text: $name)
                    Picker(L10n.Cert.typeLabel, selection: $selectedType) {
                        ForEach(vm.profileTypes) { type in
                            Text(type.label).tag(type.value)
                        }
                    }
                }

                Section(L10n.Profile.bundleId) {
                    if vm.bundleIds.isEmpty {
                        Text(L10n.Profile.noBundleId)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(L10n.Profile.bundleId, selection: $selectedBundleId) {
                            Text(L10n.select).tag("")
                            ForEach(vm.bundleIds) { bid in
                                Text("\(bid.displayName) (\(bid.identifier ?? ""))").tag(bid.id)
                            }
                        }
                    }
                }

                Section(L10n.Tab.certificates) {
                    if vm.certificates.isEmpty {
                        Text(L10n.loading)
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
                    Section(L10n.Tab.devices) {
                        if vm.devices.isEmpty {
                            Text(L10n.loading)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(L10n.selectAll) {
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
            .navigationTitle(L10n.Profile.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) { create() }
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
