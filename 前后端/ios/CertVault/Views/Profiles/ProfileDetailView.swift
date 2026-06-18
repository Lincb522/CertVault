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
        .navigationTitle(L10n.Profile.detail)
        .sheetNavStyle()
        .task { await loadDetail() }
        .glassSheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert(L10n.Profile.deleteTitle, isPresented: $showDeleteConfirm) {
            Button(L10n.delete, role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Profile.deleteMessage)
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

            Text(d.name ?? L10n.unnamed)
                .font(.headline)
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let type = d.type {
                    StatusBadge(profileTypeLabel(type), color: .dsAccentBlue)
                }
                if d.has_file == true {
                    StatusBadge(L10n.Profile.downloadable, color: .dsAccent)
                }
                if let exp = d.expires_at, isExpired(exp) {
                    StatusBadge(Localized.status("EXPIRED"), color: .dsAccentPink)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Info

    private func infoCard(_ d: ProfileDetail) -> some View {
        VStack(spacing: 0) {
            infoRow(label: NSLocalizedString("common.name", comment: ""), value: d.name ?? "-")
            Divider().padding(.leading, 16)
            infoRow(label: L10n.Cert.typeLabel, value: Localized.profileType(d.type ?? ""))
            Divider().padding(.leading, 16)
            infoRow(label: L10n.Cert.type, value: certTypeForProfile(d.type ?? ""))
            Divider().padding(.leading, 16)
            infoRow(label: L10n.Profile.bundleId, value: d.bundle_id ?? "-")
            Divider().padding(.leading, 16)
            infoRow(label: "Apple ID", value: d.apple_id ?? "-")
            Divider().padding(.leading, 16)
            infoRow(label: L10n.Cert.expiresAt, value: formatDate(d.expires_at))
            Divider().padding(.leading, 16)
            infoRow(label: L10n.Cert.createdAt, value: formatDate(d.created_at))
        }
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Bundle Info

    private func bundleInfoCard(_ bundle: ProfileBundleInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.bundleID)
                    .foregroundStyle(Color.dsAccentPurple)
                Text(L10n.Profile.bundleId)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
            }

            VStack(spacing: 0) {
                if let name = bundle.name {
                    infoRow(label: NSLocalizedString("common.name", comment: ""), value: name)
                    Divider().padding(.leading, 16)
                }
                infoRow(label: L10n.BundleID.identifier, value: bundle.identifier ?? "-")
                if let platform = bundle.platform {
                    Divider().padding(.leading, 16)
                    infoRow(label: L10n.Cert.platform, value: Localized.platform(platform))
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
                Text(L10n.Profile.relatedCerts)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.count(certs.count))
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
                            Text(cert.name ?? L10n.unnamed)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                            HStack(spacing: 6) {
                                StatusBadge(certTypeLabel(cert.type ?? ""), color: certTypeColor(cert.type ?? ""))
                                if let exp = cert.expires_at {
                                    Text(exp.toLocalDate(.short))
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
                Text(L10n.Profile.boundDevices)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.unitDevice(devices.count))
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
                        Text(L10n.Profile.noDevices)
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
                                    .lineLimit(1)
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
                                        .lineLimit(1)
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
                        Text(L10n.Profile.download).fontWeight(.medium)
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
                    Text(L10n.Profile.deleteProfile).fontWeight(.medium)
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
        Localized.profileType(type)
    }

    private func certTypeForProfile(_ profileType: String) -> String {
        let certTypeMap: [String: String] = [
            "IOS_APP_DEVELOPMENT": "IOS_DEVELOPMENT",
            "IOS_APP_STORE": "IOS_DISTRIBUTION",
            "IOS_APP_ADHOC": "IOS_DISTRIBUTION",
            "IOS_APP_INHOUSE": "IOS_DISTRIBUTION",
            "MAC_APP_DEVELOPMENT": "MAC_APP_DEVELOPMENT",
            "MAC_APP_STORE": "MAC_APP_DISTRIBUTION",
            "MAC_APP_DIRECT": "MAC_APP_DISTRIBUTION",
            "TVOS_APP_DEVELOPMENT": "IOS_DEVELOPMENT",
            "TVOS_APP_STORE": "IOS_DISTRIBUTION",
            "TVOS_APP_ADHOC": "IOS_DISTRIBUTION",
            "TVOS_APP_INHOUSE": "IOS_DISTRIBUTION",
        ]
        guard let certType = certTypeMap[profileType] else { return "-" }
        return Localized.certType(certType)
    }

    private func certTypeLabel(_ type: String) -> String {
        Localized.certType(type)
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
        return dateStr.toLocalDate(.short)
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
