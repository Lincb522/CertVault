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
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.spacing2XL) {
                    basicSection
                    bundleIdSection
                    certificatesSection

                    if needsDevices {
                        devicesSection
                    }

                    if let err = errorMsg {
                        errorSection(err)
                    }

                    createButton
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.top, DS.spacingMD)
                .padding(.bottom, DS.spacing3XL)
            }
            .pageBackground()
            .navigationTitle(L10n.Profile.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundStyle(Color.dsBrand)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) { create() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsBrand)
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

    // MARK: - Basic Section

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Account.formSectionBasic)

            DSGroupedCard {
                VStack(spacing: 0) {
                    DSInputField(
                        icon: AppIcon.profile,
                        placeholder: NSLocalizedString("profile.title", comment: ""),
                        text: $name
                    )
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.vertical, DS.spacingMD)

                    DSDivider(leadingPadding: DS.spacingLG + 20 + DS.spacingMD)

                    HStack {
                        HIcon(AppIcon.certificate)
                            .font(.callout)
                            .foregroundStyle(Color.dsBrand)
                            .frame(width: 20)

                        Picker(L10n.Cert.typeLabel, selection: $selectedType) {
                            ForEach(vm.profileTypes) { type in
                                Text(type.label).tag(type.value)
                            }
                        }
                        .tint(Color.dsBrand)
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Bundle ID Section

    private var bundleIdSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Profile.bundleId)

            DSGroupedCard {
                if vm.bundleIds.isEmpty {
                    HStack(spacing: DS.spacingMD) {
                        HIcon(AppIcon.bundleID)
                            .font(.callout)
                            .foregroundStyle(Color.dsTextTertiary)
                            .frame(width: 20)
                        Text(L10n.Profile.noBundleId)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                } else {
                    HStack {
                        HIcon(AppIcon.bundleID)
                            .font(.callout)
                            .foregroundStyle(Color.dsBrand)
                            .frame(width: 20)

                        Picker(L10n.Profile.bundleId, selection: $selectedBundleId) {
                            Text(L10n.select).tag("")
                            ForEach(vm.bundleIds) { bid in
                                Text("\(bid.displayName) (\(bid.identifier ?? ""))").tag(bid.id)
                            }
                        }
                        .tint(Color.dsBrand)
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Certificates Section

    private var certificatesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Tab.certificates)

            DSGroupedCard {
                if vm.certificates.isEmpty {
                    HStack(spacing: DS.spacingMD) {
                        HIcon(AppIcon.certificate)
                            .font(.callout)
                            .foregroundStyle(Color.dsTextTertiary)
                            .frame(width: 20)
                        Text(L10n.loading)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.certificates.enumerated()), id: \.element.id) { index, cert in
                            if index > 0 {
                                DSDivider(leadingPadding: DS.spacingLG + 20 + DS.spacingMD)
                            }

                            HStack(spacing: DS.spacingMD) {
                                HIcon(AppIcon.certificate)
                                    .font(.callout)
                                    .foregroundStyle(Color.dsTextSecondary)
                                    .frame(width: 20)

                                Text(cert.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsText)

                                Spacer()

                                if selectedCertIds.contains(cert.id) {
                                    HIcon(AppIcon.check)
                                        .font(.callout)
                                        .foregroundStyle(Color.dsBrand)
                                }
                            }
                            .padding(.vertical, DS.spacingMD)
                            .padding(.horizontal, DS.spacingLG)
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
            }
        }
    }

    // MARK: - Devices Section

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Tab.devices) {
                Button(L10n.selectAll) {
                    selectedDeviceIds = Set(vm.devices.map(\.id))
                }
                .font(.caption)
                .foregroundStyle(Color.dsBrand)
            }

            DSGroupedCard {
                if vm.devices.isEmpty {
                    HStack(spacing: DS.spacingMD) {
                        HIcon(AppIcon.device)
                            .font(.callout)
                            .foregroundStyle(Color.dsTextTertiary)
                            .frame(width: 20)
                        Text(L10n.loading)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.devices.enumerated()), id: \.element.id) { index, device in
                            if index > 0 {
                                DSDivider(leadingPadding: DS.spacingLG + 20 + DS.spacingMD)
                            }

                            HStack(spacing: DS.spacingMD) {
                                HIcon(AppIcon.device)
                                    .font(.callout)
                                    .foregroundStyle(Color.dsTextSecondary)
                                    .frame(width: 20)

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
                                        .font(.callout)
                                        .foregroundStyle(Color.dsSuccess)
                                }
                            }
                            .padding(.vertical, DS.spacingMD)
                            .padding(.horizontal, DS.spacingLG)
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
        }
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: DS.spacingSM) {
            HIcon(AppIcon.warning)
                .font(.caption)
                .foregroundStyle(Color.dsDanger)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.dsDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.spacingLG)
    }

    // MARK: - Create Button

    private var createButton: some View {
        DSPrimaryButton(
            title: L10n.create,
            isLoading: isLoading,
            isDisabled: !isValid
        ) {
            create()
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
