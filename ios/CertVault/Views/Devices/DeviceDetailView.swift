import SwiftUI
import HiconIcons

struct DeviceDetailView: View {
    let deviceId: String
    let accountId: String
    @StateObject private var vm = DeviceViewModel()
    @ObservedObject private var downloadService = FileDownloadService.shared
    @State private var copiedText: String?

    var body: some View {
        Group {
            if let device = vm.selectedDevice {
                ScrollView {
                    VStack(spacing: 20) {
                        deviceInfoCard(device)
                        certificatesSection(device)
                        profilesSection(device)
                        downloadSection(device)
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
        .navigationTitle("设备详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadDetail(deviceId: deviceId) }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Device Info

    private func deviceInfoCard(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HIcon(AppIcon.device)
                    .font(.title2)
                    .foregroundStyle(Color.dsAccent)
                    .frame(width: 48, height: 48)
                    .background(Color.dsAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Color.dsText)
                    StatusBadge.forStatus(device.status ?? "UNKNOWN")
                }
            }

            Divider().overlay(Color.dsBorder)

            Group {
                DetailRow(label: "UDID", value: device.udid ?? "N/A", monospaced: true)
                DetailRow(label: "平台", value: device.platform ?? "N/A")
                if let model = device.model {
                    DetailRow(label: "型号", value: model)
                }
                if let cls = device.device_class {
                    DetailRow(label: "类型", value: cls)
                }
                if let date = device.created_at {
                    DetailRow(label: "添加时间", value: String(date.prefix(19)))
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
                Text("关联证书")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text("\(device.certificates?.count ?? 0) 个")
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
                                    Text(cert.name ?? "未命名")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    HStack(spacing: 6) {
                                        Text(cert.type ?? "")
                                            .font(.caption)
                                            .foregroundStyle(Color.dsMuted)
                                        if let pwd = cert.password {
                                            Text("密码: \(pwd)")
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
                                        title: copiedText == pwd ? "已复制" : "复制密码",
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
                Text("暂无关联证书")
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
                Text("关联描述文件")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text("\(device.profiles?.count ?? 0) 个")
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
                                    Text(profile.name ?? "未命名")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    Text(profile.type ?? "")
                                        .font(.caption)
                                        .foregroundStyle(Color.dsMuted)
                                }
                                Spacer()
                                if profile.has_file == true {
                                    StatusBadge("可下载", color: .dsAccent)
                                }
                            }

                            PillButton(title: "下载描述文件", icon: AppIcon.docDownload, color: .dsAccentOrange) {
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
                Text("暂无关联描述文件")
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }

    // MARK: - Bundle Download

    private func downloadSection(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.download)
                    .foregroundStyle(Color.dsAccent)
                Text("打包下载")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
            }

            if let profiles = device.profiles, !profiles.isEmpty {
                Text("每个包含对应的证书 P12、描述文件和密码")
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
                                Text(profile.name ?? "未命名")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                    .lineLimit(1)
                                Text(profile.type ?? "")
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
                                    Text("下载")
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
                        Text("暂无关联的描述文件可供下载")
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
