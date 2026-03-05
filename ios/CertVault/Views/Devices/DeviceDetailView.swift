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
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let device = vm.selectedDevice {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        heroHeader(device)
                            .staggeredAppear(index: 0, animate: appeared)
                        infoSection(device)
                            .staggeredAppear(index: 1, animate: appeared)
                        certificatesSection(device)
                            .staggeredAppear(index: 2, animate: appeared)
                        profilesSection(device)
                            .staggeredAppear(index: 3, animate: appeared)
                        downloadSection(device)
                            .staggeredAppear(index: 4, animate: appeared)
                        actionsSection(device)
                            .staggeredAppear(index: 5, animate: appeared)
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(deviceId: deviceId) }
                .onAppear { withAnimation { appeared = true } }
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
            await vm.loadDetail(deviceId: deviceId)
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

    // MARK: - Hero Header

    private func heroHeader(_ device: Device) -> some View {
        let gradient: LinearGradient = device.isEnabled ? .dsGradientGreen : .dsGradientOrange
        return VStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.device)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(gradient, in: RoundedRectangle(cornerRadius: DS.radiusLG))

            Text(device.displayName)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            DSBadge.forStatus(device.status ?? "UNKNOWN")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingXL)
    }

    // MARK: - Info

    private func infoSection(_ device: Device) -> some View {
        DSGroupedCard {
            infoRow(label: L10n.Device.formUdid, value: device.udid ?? L10n.na, mono: true)
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: L10n.Cert.platform, value: Localized.platform(device.platform ?? L10n.na))
            if let model = device.model {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: NSLocalizedString("cert.model", comment: ""), value: model)
            }
            if let cls = device.device_class {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: NSLocalizedString("cert.deviceClass", comment: ""), value: Localized.deviceClass(cls))
            }
            if let date = device.created_at {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: NSLocalizedString("cert.addedAt", comment: ""), value: String(date.prefix(19)))
            }
        }
    }

    // MARK: - Certificates

    private func certificatesSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Device.relatedCerts) {
                Text(L10n.count(device.certificates?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
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
                                                .font(.dsMonoSmall)
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
                                    pillButton(title: "P12", icon: AppIcon.docDownload, color: .dsBlue) {
                                        Task { await downloadService.download(endpoint: "/certificates/\(cert.id)/download") }
                                    }
                                }

                                pillButton(title: "CER", icon: AppIcon.docDownload, color: .dsOrange) {
                                    Task { await downloadService.download(endpoint: "/certificates/\(cert.id)/download-cer") }
                                }

                                if let pwd = cert.password {
                                    pillButton(
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
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < certs.count - 1 {
                            DSDivider(leadingPadding: DS.spacingLG)
                        }
                    }
                } else {
                    Text(L10n.Device.noRelatedCerts)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Profiles

    private func profilesSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Device.relatedProfiles) {
                Text(L10n.count(device.profiles?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
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

                            pillButton(title: L10n.Profile.download, icon: AppIcon.docDownload, color: .dsOrange) {
                                Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                            }
                        }
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < profiles.count - 1 {
                            DSDivider(leadingPadding: DS.spacingLG)
                        }
                    }
                } else {
                    Text(L10n.Device.noRelatedProfiles)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Download

    private func downloadSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Device.batchDownload)

            DSGroupedCard {
                if let profiles = device.profiles, !profiles.isEmpty {
                    Text(L10n.Device.batchDownloadDesc)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.top, DS.spacingMD)

                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.profile)
                                .font(.body)
                                .foregroundStyle(Color.dsOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.dsOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusSM))

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
                                        ProgressView().controlSize(.small)
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
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < profiles.count - 1 {
                            DSDivider(leadingPadding: 60)
                        }
                    }
                } else {
                    VStack(spacing: DS.spacingSM) {
                        HIcon(AppIcon.download)
                            .foregroundStyle(Color.dsTextTertiary)
                        Text(L10n.Device.noBatchProfiles)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingLG)
                }
            }

            if let err = downloadService.errorMessage {
                Text(err).font(.caption).foregroundStyle(Color.dsRed)
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(_ device: Device) -> some View {
        VStack(spacing: DS.spacingMD) {
            DSPrimaryButton(title: L10n.Device.rebind) {
                showRebind = true
            }

            if device.isEnabled {
                DSDangerButton(L10n.Device.disableDevice, icon: AppIcon.close) {
                    showDisableConfirm = true
                }
            } else {
                Button {
                    Task {
                        isToggling = true
                        do {
                            try await vm.toggleDeviceStatus(deviceId: deviceId, enable: true)
                        } catch {
                            vm.errorMessage = error.localizedDescription
                        }
                        isToggling = false
                    }
                } label: {
                    HStack(spacing: DS.spacingSM) {
                        if isToggling {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            HIcon(AppIcon.check).font(.body)
                        }
                        Text(L10n.Device.enableDevice)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.dsGradientGreen, in: RoundedRectangle(cornerRadius: DS.radiusMD))
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            Text(value)
                .font(mono ? .dsMono : .subheadline)
                .foregroundStyle(Color.dsText)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
    }

    private func pillButton(title: String, icon: UIImage, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.spacingXS) {
                HIcon(icon).font(.caption2)
                Text(title)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
