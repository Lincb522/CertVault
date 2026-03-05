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
    @State private var appeared = false

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
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .sheet(isPresented: $downloadService.showShareSheet) {
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
            VStack(spacing: DS.spacingXL) {
                heroHeader(d)
                    .staggeredAppear(index: 0, animate: appeared)
                infoCard(d)
                    .staggeredAppear(index: 1, animate: appeared)
                if let bundle = d.bundle_info {
                    bundleInfoCard(bundle)
                        .staggeredAppear(index: 2, animate: appeared)
                }
                if let certs = d.certificates, !certs.isEmpty {
                    certificatesCard(certs)
                        .staggeredAppear(index: 3, animate: appeared)
                }
                devicesCard(d.devices ?? [])
                    .staggeredAppear(index: 4, animate: appeared)
                actionsCard(d)
                    .staggeredAppear(index: 5, animate: appeared)
            }
            .padding(DS.spacingLG)
        }
        .pageBackground()
        .refreshable { await loadDetail() }
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Hero Header

    private func heroHeader(_ d: ProfileDetail) -> some View {
        VStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.profile)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.dsGradientOrange, in: RoundedRectangle(cornerRadius: DS.radiusLG))

            Text(d.name ?? L10n.unnamed)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            HStack(spacing: DS.spacingSM) {
                if let type = d.type {
                    DSBadge(text: profileTypeLabel(type), color: .dsBlue)
                }
                if d.has_file == true {
                    DSBadge(text: L10n.Profile.downloadable, color: .dsGreen)
                }
                if let exp = d.expires_at, isExpired(exp) {
                    DSBadge.forStatus("EXPIRED")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingXL)
    }

    // MARK: - Info

    private func infoCard(_ d: ProfileDetail) -> some View {
        DSGroupedCard {
            infoRow(label: NSLocalizedString("common.name", comment: ""), value: d.name ?? "-")
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: L10n.Cert.typeLabel, value: Localized.profileType(d.type ?? ""))
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: L10n.Cert.type, value: certTypeForProfile(d.type ?? ""))
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: L10n.Profile.bundleId, value: d.bundle_id ?? "-")
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: "Apple ID", value: d.apple_id ?? "-")
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: L10n.Cert.expiresAt, value: formatDate(d.expires_at))
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: L10n.Cert.createdAt, value: formatDate(d.created_at))
        }
    }

    // MARK: - Bundle Info

    private func bundleInfoCard(_ bundle: ProfileBundleInfo) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Profile.bundleId)

            DSGroupedCard {
                if let name = bundle.name {
                    infoRow(label: NSLocalizedString("common.name", comment: ""), value: name)
                    DSDivider(leadingPadding: DS.spacingLG)
                }
                infoRow(label: L10n.BundleID.identifier, value: bundle.identifier ?? "-")
                if let platform = bundle.platform {
                    DSDivider(leadingPadding: DS.spacingLG)
                    infoRow(label: L10n.Cert.platform, value: Localized.platform(platform))
                }
            }
        }
    }

    // MARK: - Certificates

    private func certificatesCard(_ certs: [ProfileLinkedCert]) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Profile.relatedCerts) {
                Text(L10n.count(certs.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
            }

            DSGroupedCard {
                ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cert.name ?? L10n.unnamed)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                            HStack(spacing: DS.spacingSM) {
                                DSBadge(text: certTypeLabel(cert.type ?? ""), color: certTypeColor(cert.type ?? ""))
                                if let exp = cert.expires_at {
                                    Text(String(exp.prefix(10)))
                                        .font(.dsMonoSmall)
                                        .foregroundStyle(isExpired(exp) ? Color.dsRed : Color.dsTextSecondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, DS.spacingSM)
                    .padding(.horizontal, DS.spacingLG)

                    if index < certs.count - 1 {
                        DSDivider(leadingPadding: DS.spacingLG)
                    }
                }
            }
        }
    }

    // MARK: - Devices

    private func devicesCard(_ devices: [ProfileLinkedDevice]) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Profile.boundDevices) {
                Text(L10n.unitDevice(devices.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
            }

            DSGroupedCard {
                if devices.isEmpty {
                    VStack(spacing: DS.spacingSM) {
                        HIcon(AppIcon.device)
                            .foregroundStyle(Color.dsTextTertiary)
                        Text(L10n.Profile.noDevices)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingLG)
                } else {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.device)
                                .font(.body)
                                .foregroundStyle(Color.dsGreen)
                                .frame(width: 36, height: 36)
                                .background(Color.dsGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                if let udid = device.udid {
                                    Text(udid)
                                        .font(.dsMonoSmall)
                                        .foregroundStyle(Color.dsTextSecondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                if let platform = device.platform {
                                    Text(platform)
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                                DSBadge.forStatus(device.status ?? "UNKNOWN")
                            }
                        }
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < devices.count - 1 {
                            DSDivider(leadingPadding: 60)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsCard(_ d: ProfileDetail) -> some View {
        VStack(spacing: DS.spacingMD) {
            if d.has_file == true {
                DSPrimaryButton(title: L10n.Profile.download) {
                    Task {
                        await downloadService.download(endpoint: "/profiles/\(profileId)/download")
                    }
                }
            }

            DSDangerButton(L10n.Profile.deleteProfile, icon: AppIcon.delete) {
                showDeleteConfirm = true
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
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
            return .dsBlue
        } else if type.contains("DISTRIBUTION") || type == "DISTRIBUTION" {
            return .dsPurple
        } else {
            return .dsOrange
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
