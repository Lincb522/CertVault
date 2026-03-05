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
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.Account.formSectionBasic)
                            DSInputField(icon: AppIcon.edit, placeholder: NSLocalizedString("profile.title", comment: ""), text: $name)
                            HStack {
                                Text(L10n.Cert.typeLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsTextSecondary)
                                Spacer()
                                Picker(L10n.Cert.typeLabel, selection: $selectedType) {
                                    ForEach(vm.profileTypes) { type in
                                        Text(type.label).tag(type.value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.dsBrand)
                            }
                            .padding(.horizontal, DS.spacingXS)
                        }
                        .padding(DS.spacingLG)
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.Profile.bundleId)
                            if vm.bundleIds.isEmpty {
                                Text(L10n.Profile.noBundleId)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsTextSecondary)
                                    .padding(.horizontal, DS.spacingXS)
                            } else {
                                Picker(L10n.Profile.bundleId, selection: $selectedBundleId) {
                                    Text(L10n.select).tag("")
                                    ForEach(vm.bundleIds) { bid in
                                        Text("\(bid.displayName) (\(bid.identifier ?? ""))").tag(bid.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.dsBrand)
                            }
                        }
                        .padding(DS.spacingLG)
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            DSSectionHeader(L10n.Tab.certificates)
                                .padding(.bottom, DS.spacingXS)

                            if vm.certificates.isEmpty {
                                Text(L10n.loading)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsTextSecondary)
                            } else {
                                ForEach(vm.certificates) { cert in
                                    HStack {
                                        Text(cert.displayName)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.dsText)
                                        Spacer()
                                        if selectedCertIds.contains(cert.id) {
                                            HIcon(AppIcon.check)
                                                .foregroundStyle(Color.dsBrand)
                                        }
                                    }
                                    .padding(.vertical, DS.spacingSM)
                                    .padding(.horizontal, DS.spacingXS)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedCertIds.contains(cert.id) {
                                            selectedCertIds.remove(cert.id)
                                        } else {
                                            selectedCertIds.insert(cert.id)
                                        }
                                    }

                                    if cert.id != vm.certificates.last?.id {
                                        DSDivider(leadingPadding: 0)
                                    }
                                }
                            }
                        }
                        .padding(DS.spacingLG)
                    }

                    if needsDevices {
                        DSGroupedCard {
                            VStack(alignment: .leading, spacing: DS.spacingSM) {
                                HStack {
                                    DSSectionHeader(L10n.Tab.devices)
                                    Spacer()
                                    Button(L10n.selectAll) {
                                        selectedDeviceIds = Set(vm.devices.map(\.id))
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.dsBrand)
                                }
                                .padding(.bottom, DS.spacingXS)

                                if vm.devices.isEmpty {
                                    Text(L10n.loading)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsTextSecondary)
                                } else {
                                    ForEach(vm.devices) { device in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(device.displayName)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.dsText)
                                                Text(device.udid ?? "")
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(Color.dsTextSecondary)
                                            }
                                            Spacer()
                                            if selectedDeviceIds.contains(device.id) {
                                                HIcon(AppIcon.check)
                                                    .foregroundStyle(Color.dsSuccess)
                                            }
                                        }
                                        .padding(.vertical, DS.spacingSM)
                                        .padding(.horizontal, DS.spacingXS)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if selectedDeviceIds.contains(device.id) {
                                                selectedDeviceIds.remove(device.id)
                                            } else {
                                                selectedDeviceIds.insert(device.id)
                                            }
                                        }

                                        if device.id != vm.devices.last?.id {
                                            DSDivider(leadingPadding: 0)
                                        }
                                    }
                                }
                            }
                            .padding(DS.spacingLG)
                        }
                    }

                    if let err = errorMsg {
                        Text(err)
                            .foregroundStyle(Color.dsDanger)
                            .font(.caption)
                    }

                    DSPrimaryButton(title: L10n.create, isLoading: isLoading, isDisabled: !isValid) {
                        create()
                    }
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(L10n.Profile.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
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
