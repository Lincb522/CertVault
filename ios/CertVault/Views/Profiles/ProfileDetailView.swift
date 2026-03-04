import SwiftUI
import HiconIcons

struct ProfileDetailView: View {
    let profileId: String
    let onDelete: () async -> Void
    @ObservedObject private var downloadService = FileDownloadService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ProfileDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private let service = ProfileService()

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let err = errorMessage {
                ErrorView(message: err) { Task { await loadDetail() } }
            } else if let d = detail {
                contentView(d)
            }
        }
        .navigationTitle("描述文件详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将同时从 Apple Developer 移除，此操作不可撤销。")
        }
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await service.detail(id: profileId)
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    @ViewBuilder
    private func contentView(_ d: ProfileDetail) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard(d)
                infoCard(d)
                if let bundle = d.bundle_info {
                    bundleInfoCard(bundle)
                }
                if let certs = d.certificates, !certs.isEmpty {
                    certificatesCard(certs)
                }
                devicesCard(d.devices ?? [])
                actionsCard(d)
            }
            .padding(16)
        }
        .pageBackground()
        .refreshable { await loadDetail() }
    }

    // MARK: - Header

    private func headerCard(_ d: ProfileDetail) -> some View {
        VStack(spacing: 12) {
            HIcon(AppIcon.profile)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(colors: [.dsAccentOrange, .dsAccentPink],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                )

            Text(d.name ?? "未命名")
                .font(.headline)
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let type = d.type {
                    StatusBadge(profileTypeLabel(type), color: .dsAccentBlue)
                }
                if d.has_file == true {
                    StatusBadge("可下载", color: .dsAccent)
                }
                if let exp = d.expires_at, isExpired(exp) {
                    StatusBadge("已过期", color: .dsAccentPink)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
    }

    // MARK: - Info

    private func infoCard(_ d: ProfileDetail) -> some View {
        VStack(spacing: 0) {
            infoRow(label: "名称", value: d.name ?? "-")
            Divider().padding(.leading, 16)
            infoRow(label: "类型", value: profileTypeLabel(d.type ?? ""))
            Divider().padding(.leading, 16)
            infoRow(label: "证书类型", value: certTypeForProfile(d.type ?? ""))
            Divider().padding(.leading, 16)
            infoRow(label: "Bundle ID", value: d.bundle_id ?? "-")
            Divider().padding(.leading, 16)
            infoRow(label: "Apple ID", value: d.apple_id ?? "-")
            Divider().padding(.leading, 16)
            infoRow(label: "过期时间", value: formatDate(d.expires_at))
            Divider().padding(.leading, 16)
            infoRow(label: "创建时间", value: formatDate(d.created_at))
        }
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
    }

    // MARK: - Bundle Info

    private func bundleInfoCard(_ bundle: ProfileBundleInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.bundleID)
                    .foregroundStyle(Color.dsAccentPurple)
                Text("Bundle ID")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
            }

            VStack(spacing: 0) {
                if let name = bundle.name {
                    infoRow(label: "名称", value: name)
                    Divider().padding(.leading, 16)
                }
                infoRow(label: "标识符", value: bundle.identifier ?? "-")
                if let platform = bundle.platform {
                    Divider().padding(.leading, 16)
                    infoRow(label: "平台", value: platform)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Certificates

    private func certificatesCard(_ certs: [ProfileLinkedCert]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.certificate)
                    .foregroundStyle(Color.dsAccentBlue)
                Text("关联证书")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text("\(certs.count) 个")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cert.name ?? "未命名")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                            HStack(spacing: 6) {
                                StatusBadge(certTypeLabel(cert.type ?? ""), color: certTypeColor(cert.type ?? ""))
                                if let exp = cert.expires_at {
                                    Text(String(exp.prefix(10)))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(isExpired(exp) ? Color.dsAccentPink : Color.dsMuted)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)

                    if index < certs.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Devices

    private func devicesCard(_ devices: [ProfileLinkedDevice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.device)
                    .foregroundStyle(Color.dsAccent)
                Text("绑定设备")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text("\(devices.count) 台")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if devices.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        HIcon(AppIcon.device)
                            .foregroundStyle(Color.dsMuted.opacity(0.4))
                        Text("暂无绑定设备")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        HStack(spacing: 12) {
                            HIcon(AppIcon.device)
                                .font(.body)
                                .foregroundStyle(Color.dsAccent)
                                .frame(width: 36, height: 36)
                                .background(Color.dsAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                if let udid = device.udid {
                                    Text(udid)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Color.dsMuted)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                if let platform = device.platform {
                                    Text(platform)
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsMuted)
                                }
                                StatusBadge.forStatus(device.status ?? "UNKNOWN")
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)

                        if index < devices.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func actionsCard(_ d: ProfileDetail) -> some View {
        VStack(spacing: 10) {
            if d.has_file == true {
                Button {
                    Task {
                        await downloadService.download(endpoint: "/profiles/\(profileId)/download")
                    }
                } label: {
                    Label {
                        Text("下载描述文件").fontWeight(.medium)
                    } icon: {
                        HIcon(AppIcon.docDownload)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.dsAccentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label {
                    Text("删除描述文件").fontWeight(.medium)
                } icon: {
                    HIcon(AppIcon.delete)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.dsAccentPink)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func profileTypeLabel(_ type: String) -> String {
        let map: [String: String] = [
            "IOS_APP_DEVELOPMENT": "iOS 开发",
            "IOS_APP_STORE": "App Store",
            "IOS_APP_ADHOC": "Ad Hoc",
            "IOS_APP_INHOUSE": "企业内部",
            "MAC_APP_DEVELOPMENT": "macOS 开发",
            "MAC_APP_STORE": "Mac App Store",
            "MAC_APP_DIRECT": "macOS 直接分发",
            "TVOS_APP_DEVELOPMENT": "tvOS 开发",
            "TVOS_APP_STORE": "tvOS App Store",
            "TVOS_APP_ADHOC": "tvOS Ad Hoc",
            "TVOS_APP_INHOUSE": "tvOS 企业",
        ]
        return map[type] ?? type
    }

    private func certTypeForProfile(_ profileType: String) -> String {
        let map: [String: String] = [
            "IOS_APP_DEVELOPMENT": "iOS 开发证书",
            "IOS_APP_STORE": "iOS 发布证书",
            "IOS_APP_ADHOC": "iOS 发布证书",
            "IOS_APP_INHOUSE": "iOS 发布证书",
            "MAC_APP_DEVELOPMENT": "macOS 开发证书",
            "MAC_APP_STORE": "macOS 发布证书",
            "MAC_APP_DIRECT": "macOS 发布证书",
            "TVOS_APP_DEVELOPMENT": "iOS 开发证书",
            "TVOS_APP_STORE": "iOS 发布证书",
            "TVOS_APP_ADHOC": "iOS 发布证书",
            "TVOS_APP_INHOUSE": "iOS 发布证书",
        ]
        return map[profileType] ?? "-"
    }

    private func certTypeLabel(_ type: String) -> String {
        let map: [String: String] = [
            "IOS_DEVELOPMENT": "开发",
            "IOS_DISTRIBUTION": "发布",
            "DEVELOPMENT": "开发",
            "DISTRIBUTION": "发布",
            "MAC_APP_DEVELOPMENT": "macOS 开发",
            "MAC_APP_DISTRIBUTION": "macOS 发布",
            "MAC_INSTALLER_DISTRIBUTION": "macOS 安装包",
            "DEVELOPER_ID_APPLICATION": "Developer ID",
            "DEVELOPER_ID_INSTALLER": "Developer ID 安装器",
            "DEVELOPER_ID_KEXT": "Developer ID 内核扩展",
        ]
        return map[type] ?? type
    }

    private func certTypeColor(_ type: String) -> Color {
        if type.contains("DEVELOPMENT") || type == "DEVELOPMENT" {
            return .dsAccentBlue
        } else if type.contains("DISTRIBUTION") || type == "DISTRIBUTION" {
            return .dsAccentPurple
        } else {
            return .dsAccentOrange
        }
    }

    private func formatDate(_ dateStr: String?) -> String {
        guard let dateStr else { return "-" }
        return dateStr.count >= 10 ? String(dateStr.prefix(10)) : dateStr
    }

    private func isExpired(_ dateStr: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) { return date < Date() }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateStr) { return date < Date() }
        return false
    }
}
