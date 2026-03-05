import SwiftUI
import HiconIcons

struct DeviceDetailView: View {
    let deviceId: String
    let accountId: String
    @StateObject private var vm = DeviceViewModel()
    @ObservedObject private var downloadService = FileDownloadService.shared
    @State private var copiedText: String?
    @State private var showDisableConfirm = false
    @State private var showRebind = false
    @State private var isToggling = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let device = vm.selectedDevice {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        deviceInfoCard(device)
                        certificatesSection(device)
                        profilesSection(device)
                        downloadSection(device)
                        actionsSection(device)
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacing2XL)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(deviceId: deviceId) }
            } else if vm.isLoading {
                LoadingView()
            } else if let err = vm.errorMessage {
                ErrorView(message: err) { Task { await vm.loadDetail(deviceId: deviceId) } }
            } else {
                LoadingView()
            }
        }
        .navigationTitle(L10n.Device.detail)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.selectedAccountId = accountId
            async let detail: () = vm.loadDetail(deviceId: deviceId)
            async let accounts: () = vm.loadAccounts()
            _ = await (detail, accounts)
        }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showRebind) {
            if let device = vm.selectedDevice {
                AutoBindView(
                    vm: vm,
                    prefillName: device.displayName,
                    prefillUDID: device.udid ?? ""
                )
            }
        }
        .alert(L10n.Device.disableTitle, isPresented: $showDisableConfirm) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.Device.disableDevice, role: .destructive) {
                Task {
                    isToggling = true
                    do {
                        try await vm.toggleDeviceStatus(deviceId: deviceId, enable: false)
                    } catch {
                        vm.errorMessage = error.localizedDescription
                    }
                    isToggling = false
                }
            }
        } message: {
            Text(L10n.Device.disableMessage)
        }
    }

    // MARK: - Device Info

    private func deviceInfoCard(_ device: Device) -> some View {
        let tint: Color = device.isEnabled ? .dsGreen : (device.isIneligible ? .dsOrange : .dsDanger)
        return DSGroupedCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DS.spacingMD) {
                    HIcon(AppIcon.device)
                        .font(.title2)
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusMD))

                    VStack(alignment: .leading, spacing: DS.spacingXS) {
                        Text(device.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(device.isEnabled ? Color.dsText : Color.dsDanger)
                        DSBadge.forStatus(device.status ?? "UNKNOWN")
                    }
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingMD)

                DSDivider(leadingPadding: 0)

                VStack(spacing: 0) {
                    DetailRow(label: L10n.Device.formUdid, value: device.udid ?? L10n.na, monospaced: true)
                    DSDivider(leadingPadding: 0)
                    DetailRow(label: L10n.Cert.platform, value: Localized.platform(device.platform ?? L10n.na))
                    if let model = device.model {
                        DSDivider(leadingPadding: 0)
                        DetailRow(label: NSLocalizedString("cert.model", comment: ""), value: model)
                    }
                    if let cls = device.device_class {
                        DSDivider(leadingPadding: 0)
                        DetailRow(label: NSLocalizedString("cert.deviceClass", comment: ""), value: Localized.deviceClass(cls))
                    }
                    if let date = device.created_at {
                        DSDivider(leadingPadding: 0)
                        DetailRow(label: NSLocalizedString("cert.addedAt", comment: ""), value: String(date.prefix(19)))
                    }
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.vertical, DS.spacingMD)
            }
        }
    }

    // MARK: - Certificates

    private func certificatesSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Device.relatedCerts) {
                DSBadge(text: L10n.count(device.certificates?.count ?? 0), color: .dsTextSecondary)
            }

            DSGroupedCard {
                if let certs = device.certificates, !certs.isEmpty {
                    ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.name ?? L10n.unnamed)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    HStack(spacing: DS.spacingSM) {
                                        Text(cert.type ?? "")
                                            .font(.caption)
                                            .foregroundStyle(Color.dsTextSecondary)
                                        if let pwd = cert.password {
                                            Text("\(L10n.Cert.password): \(pwd)")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Color.dsBlue)
                                        }
                                    }
                                }
                                Spacer()
                                if cert.has_p12 == true {
                                    DSBadge(text: "P12", color: .dsBlue)
                                }
                            }

                            HStack(spacing: DS.spacingSM) {
                                if cert.canDownloadP12 {
                                    ActionChip(title: "P12", icon: AppIcon.docDownload, color: .dsBlue) {
                                        Task { await downloadService.download(endpoint: "/certificates/\(cert.id)/download") }
                                    }
                                }

                                ActionChip(title: "CER", icon: AppIcon.docDownload, color: .dsOrange) {
                                    Task { await downloadService.download(endpoint: "/certificates/\(cert.id)/download-cer") }
                                }

                                if let pwd = cert.password {
                                    ActionChip(
                                        title: copiedText == pwd ? NSLocalizedString("common.done", comment: "") : NSLocalizedString("common.copy", comment: ""),
                                        icon: copiedText == pwd ? AppIcon.check : AppIcon.copy,
                                        color: .dsGreen
                                    ) {
                                        UIPasteboard.general.string = pwd
                                        withAnimation { copiedText = pwd }
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.vertical, DS.spacingMD)

                        if index < certs.count - 1 {
                            DSDivider(leadingPadding: DS.spacingLG)
                        }
                    }
                } else {
                    Text(L10n.Device.noRelatedCerts)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.vertical, DS.spacing2XL)
                }
            }
        }
    }

    // MARK: - Profiles

    private func profilesSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Device.relatedProfiles) {
                DSBadge(text: L10n.count(device.profiles?.count ?? 0), color: .dsTextSecondary)
            }

            DSGroupedCard {
                if let profiles = device.profiles, !profiles.isEmpty {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        VStack(alignment: .leading, spacing: DS.spacingSM) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name ?? L10n.unnamed)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.profileType(profile.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                                Spacer()
                                if profile.has_file == true {
                                    DSBadge(text: L10n.Profile.downloadable, color: .dsGreen)
                                }
                            }

                            ActionChip(title: L10n.Profile.download, icon: AppIcon.docDownload, color: .dsOrange) {
                                Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                            }
                        }
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.vertical, DS.spacingMD)

                        if index < profiles.count - 1 {
                            DSDivider(leadingPadding: DS.spacingLG)
                        }
                    }
                } else {
                    Text(L10n.Device.noRelatedProfiles)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.vertical, DS.spacing2XL)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(_ device: Device) -> some View {
        VStack(spacing: DS.spacingMD) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showRebind = true
            } label: {
                HStack(spacing: DS.spacingSM) {
                    HIcon(AppIcon.link).font(.body)
                    Text(L10n.Device.rebind)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
                .contentShape(Rectangle())
            }
            .buttonStyle(.dsPressed)

            if device.isEnabled {
                DSDangerButton(L10n.Device.disableDevice, icon: AppIcon.close) {
                    showDisableConfirm = true
                }
                .overlay {
                    if isToggling {
                        ProgressView().tint(.dsDanger)
                    }
                }
                .disabled(isToggling)
            } else {
                DSPrimaryButton(
                    title: L10n.Device.enableDevice,
                    isLoading: isToggling
                ) {
                    Task {
                        isToggling = true
                        do {
                            try await vm.toggleDeviceStatus(deviceId: deviceId, enable: true)
                        } catch {
                            vm.errorMessage = error.localizedDescription
                        }
                        isToggling = false
                    }
                }
            }
        }
    }

    // MARK: - Bundle Download

    private func downloadSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Device.batchDownload)

            DSGroupedCard {
                if let profiles = device.profiles, !profiles.isEmpty {
                    Text(L10n.Device.batchDownloadDesc)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.top, DS.spacingMD)

                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.profile)
                                .font(.body)
                                .foregroundStyle(Color.dsOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.dsOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name ?? L10n.unnamed)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                    .lineLimit(1)
                                Text(Localized.profileType(profile.type ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(Color.dsTextSecondary)
                            }

                            Spacer()

                            Button {
                                Task {
                                    await downloadService.download(
                                        endpoint: "/devices/\(deviceId)/download-bundle",
                                        queryItems: [
                                            URLQueryItem(name: "profile_id", value: profile.id)
                                        ]
                                    )
                                }
                            } label: {
                                HStack(spacing: DS.spacingXS) {
                                    if downloadService.isDownloading {
                                        ProgressView().controlSize(.small).tint(.white)
                                    } else {
                                        HIcon(AppIcon.download).font(.caption2)
                                    }
                                    Text(L10n.download)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, DS.spacingMD)
                                .padding(.vertical, 7)
                                .foregroundStyle(.white)
                                .background(Color.dsGreen, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.vertical, DS.spacingMD)

                        if index < profiles.count - 1 {
                            DSDivider(leadingPadding: 52)
                        }
                    }
                } else {
                    VStack(spacing: DS.spacingSM) {
                        HIcon(AppIcon.download)
                            .font(.system(size: 32))
                            .foregroundStyle(Color.dsTextTertiary.opacity(0.6))
                        Text(L10n.Device.noBatchProfiles)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacing2XL)
                }

                if let err = downloadService.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color.dsDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.bottom, DS.spacingMD)
                }
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text(value)
                .font(monospaced ? .subheadline.monospaced() : .subheadline)
                .foregroundStyle(Color.dsText)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Action Chip (compact pill-style button)

private struct ActionChip: View {
    let title: String
    let icon: UIImage
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.spacingXS) {
                HIcon(icon).font(.caption2)
                Text(title)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, DS.spacingMD)
            .padding(.vertical, DS.spacingSM)
            .foregroundStyle(color)
            .background(color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
