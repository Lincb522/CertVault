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
                    VStack(spacing: 20) {
                        deviceInfoCard(device)
                        certificatesSection(device)
                        profilesSection(device)
                        downloadSection(device)
                        actionsSection(device)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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

    // MARK: - Device Info

    private func deviceInfoCard(_ device: Device) -> some View {
        let tint: Color = device.isEnabled ? .dsAccent : (device.isIneligible ? .dsAccentOrange : .dsAccentPink)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HIcon(AppIcon.device)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(device.isEnabled ? Color.dsText : Color.dsAccentPink)
                    StatusBadge.forStatus(device.status ?? "UNKNOWN")
                }
            }

            Divider().overlay(Color.dsBorder)

            Group {
                DetailRow(label: L10n.Device.formUdid, value: device.udid ?? L10n.na, monospaced: true)
                DetailRow(label: L10n.Cert.platform, value: Localized.platform(device.platform ?? L10n.na))
                if let model = device.model {
                    DetailRow(label: NSLocalizedString("cert.model", comment: ""), value: model)
                }
                if let cls = device.device_class {
                    DetailRow(label: NSLocalizedString("cert.deviceClass", comment: ""), value: Localized.deviceClass(cls))
                }
                if let date = device.created_at {
                    DetailRow(label: NSLocalizedString("cert.addedAt", comment: ""), value: String(date.prefix(19)))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Certificates

    private func certificatesSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.certificate)
                    .foregroundStyle(Color.dsAccentPurple)
                Text(L10n.Device.relatedCerts)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.count(device.certificates?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if let certs = device.certificates, !certs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.name ?? L10n.unnamed)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    HStack(spacing: 6) {
                                        Text(cert.type ?? "")
                                            .font(.caption)
                                            .foregroundStyle(Color.dsMuted)
                                        if let pwd = cert.password {
                                            Text("\(L10n.Cert.password): \(pwd)")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Color.dsAccentBlue)
                                        }
                                    }
                                }
                                Spacer()
                                if cert.has_p12 == true {
                                    StatusBadge("P12", color: .dsAccentBlue)
                                }
                            }

                            HStack(spacing: 8) {
                                if cert.canDownloadP12 {
                                    PillButton(title: "P12", icon: AppIcon.docDownload, color: .dsAccentBlue) {
                                        Task { await downloadService.download(endpoint: "/certificates/\(cert.id)/download") }
                                    }
                                }

                                PillButton(title: "CER", icon: AppIcon.docDownload, color: .dsAccentOrange) {
                                    Task { await downloadService.download(endpoint: "/certificates/\(cert.id)/download-cer") }
                                }

                                if let pwd = cert.password {
                                    PillButton(
                                        title: copiedText == pwd ? NSLocalizedString("common.done", comment: "") : NSLocalizedString("common.copy", comment: ""),
                                        icon: copiedText == pwd ? AppIcon.check : AppIcon.copy,
                                        color: .dsAccent
                                    ) {
                                        UIPasteboard.general.string = pwd
                                        withAnimation { copiedText = pwd }
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)

                        if index < certs.count - 1 {
                            Divider().overlay(Color.dsBorder)
                        }
                    }
                }
            } else {
                Text(L10n.Device.noRelatedCerts)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }

    // MARK: - Profiles

    private func profilesSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.profile)
                    .foregroundStyle(Color.dsAccentOrange)
                Text(L10n.Device.relatedProfiles)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.count(device.profiles?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if let profiles = device.profiles, !profiles.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name ?? L10n.unnamed)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.profileType(profile.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsMuted)
                                }
                                Spacer()
                                if profile.has_file == true {
                                    StatusBadge(L10n.Profile.downloadable, color: .dsAccent)
                                }
                            }

                            PillButton(title: L10n.Profile.download, icon: AppIcon.docDownload, color: .dsAccentOrange) {
                                Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                            }
                        }
                        .padding(.vertical, 10)

                        if index < profiles.count - 1 {
                            Divider().overlay(Color.dsBorder)
                        }
                    }
                }
            } else {
                Text(L10n.Device.noRelatedProfiles)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func actionsSection(_ device: Device) -> some View {
        VStack(spacing: 12) {
            Button {
                showRebind = true
            } label: {
                HStack(spacing: 8) {
                    HIcon(AppIcon.link).font(.body)
                    Text(L10n.Device.rebind)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color.dsAccentBlue, Color.dsAccentPurple],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)

            if device.isEnabled {
                Button {
                    showDisableConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        if isToggling {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            HIcon(AppIcon.close).font(.body)
                        }
                        Text(L10n.Device.disableDevice)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.dsAccentPink, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
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
                    HStack(spacing: 8) {
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
                    .background(
                        LinearGradient(
                            colors: [Color.dsAccent, Color(red: 0.10, green: 0.60, blue: 0.40)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Bundle Download

    private func downloadSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.download)
                    .foregroundStyle(Color.dsAccent)
                Text(L10n.Device.batchDownload)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
            }

            if let profiles = device.profiles, !profiles.isEmpty {
                Text(L10n.Device.batchDownloadDesc)
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)

                VStack(spacing: 0) {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        HStack(spacing: 12) {
                            HIcon(AppIcon.profile)
                                .font(.body)
                                .foregroundStyle(Color.dsAccentOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.dsAccentOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name ?? L10n.unnamed)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                    .lineLimit(1)
                                Text(Localized.profileType(profile.type ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
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
                                HStack(spacing: 4) {
                                    if downloadService.isDownloading {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        HIcon(AppIcon.download).font(.caption2)
                                    }
                                    Text(L10n.download)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .foregroundStyle(.white)
                                .background(Color.dsAccent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)

                        if index < profiles.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        HIcon(AppIcon.download)
                            .foregroundStyle(Color.dsMuted.opacity(0.4))
                        Text(L10n.Device.noBatchProfiles)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            }

            if let err = downloadService.errorMessage {
                Text(err).font(.caption).foregroundStyle(Color.dsAccentPink)
            }
        }
        .cardStyle()
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
                .foregroundStyle(Color.dsMuted)
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

// MARK: - Pill Button

private struct PillButton: View {
    let title: String
    let icon: UIImage
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
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
