import SwiftUI
import HiconIcons

struct BundleIDDetailView: View {
    let bundleId: BundleIDItem
    let accountId: String
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var capabilities: [CapabilityItem] = []
    @State private var resources: BundleIDResources?
    @State private var isLoadingCaps = false
    @State private var isLoadingResources = false
    @State private var showDeleteConfirm = false
    @State private var copiedText: String?

    private let capService = CapabilityService()
    private let profileService = ProfileService()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingXL) {
                infoCard
                devicesSection
                certificatesSection
                profilesSection
                capabilitiesSection
                deleteSection
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacingXL)
        }
        .pageBackground()
        .navigationTitle(L10n.BundleID.detail)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let caps: () = loadCapabilities()
            async let res: () = loadResources()
            _ = await (caps, res)
        }
        .alert(L10n.BundleID.deleteTitle, isPresented: $showDeleteConfirm) {
            Button(L10n.delete, role: .destructive) {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.BundleID.deleteMessage)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            HStack(spacing: DS.spacingMD) {
                HIcon(AppIcon.bundleID)
                    .font(.title2)
                    .foregroundStyle(Color.dsCyan)
                    .frame(width: 48, height: 48)
                    .background(Color.dsCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusLG))

                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(bundleId.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Color.dsText)
                    if let platform = bundleId.platform {
                        DSBadge(text: platform, color: .dsBlue)
                    }
                }
            }

            DSDivider(leadingPadding: 0)

            detailRow(L10n.BundleID.identifier, value: bundleId.identifier ?? L10n.na, monospaced: true, copyable: true)
            detailRow(NSLocalizedString("common.name", comment: ""), value: bundleId.name ?? L10n.na)
            detailRow(L10n.Cert.platform, value: Localized.platform(bundleId.platform ?? L10n.na))
            if let date = bundleId.created_at {
                detailRow(L10n.Cert.createdAt, value: String(date.prefix(19)))
            }
        }
        .cardStyle()
    }

    // MARK: - Devices

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.relatedDevices) {
                DSBadge(text: L10n.count(resources?.devices?.count ?? 0), color: .dsTextSecondary)
            }

            DSGroupedCard {
                if isLoadingResources {
                    loadingPlaceholder
                } else if let devices = resources?.devices, !devices.isEmpty {
                    ForEach(devices) { device in
                        NavigationLink {
                            DeviceDetailView(deviceId: device.id, accountId: accountId)
                        } label: {
                            DSRow(
                                icon: AppIcon.device,
                                iconColor: .dsGreen,
                                title: device.displayName,
                                subtitle: device.udid,
                                trailing: device.status != nil ? AnyView(DSBadge.forStatus(device.status!)) : nil,
                                showChevron: false
                            )
                        }
                        .buttonStyle(.dsPressed)

                        if device.id != devices.last?.id {
                            DSDivider()
                        }
                    }
                } else {
                    Text(L10n.BundleID.noDevices)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.vertical, DS.spacingMD)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Certificates

    private var certificatesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.relatedCerts) {
                DSBadge(text: L10n.count(resources?.certificates?.count ?? 0), color: .dsTextSecondary)
            }

            DSGroupedCard {
                if isLoadingResources {
                    loadingPlaceholder
                } else if let certs = resources?.certificates, !certs.isEmpty {
                    ForEach(certs) { cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id, accountId: accountId)
                        } label: {
                            HStack(spacing: DS.spacingMD) {
                                HIcon(AppIcon.certificate)
                                    .font(.callout)
                                    .foregroundStyle(Color.dsPurple)
                                    .frame(width: 32, height: 32)
                                    .background(Color.dsPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    HStack(spacing: DS.spacingSM) {
                                        Text(Localized.certType(cert.type ?? ""))
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

                                HIcon(AppIcon.chevronRight)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsTextTertiary)
                            }
                            .padding(.vertical, DS.spacingMD)
                            .padding(.horizontal, DS.spacingLG)
                            .frame(minHeight: DS.minTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.dsPressed)

                        if cert.id != certs.last?.id {
                            DSDivider()
                        }
                    }
                } else {
                    Text(L10n.BundleID.noCerts)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.vertical, DS.spacingMD)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Profiles

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.relatedProfiles) {
                DSBadge(text: L10n.count(resources?.profiles?.count ?? 0), color: .dsTextSecondary)
            }

            DSGroupedCard {
                if isLoadingResources {
                    loadingPlaceholder
                } else if let profiles = resources?.profiles, !profiles.isEmpty {
                    ForEach(profiles) { profile in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.profile)
                                .font(.callout)
                                .foregroundStyle(Color.dsOrange)
                                .frame(width: 32, height: 32)
                                .background(Color.dsOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
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
                        .padding(.vertical, DS.spacingMD)
                        .padding(.horizontal, DS.spacingLG)

                        if profile.id != profiles.last?.id {
                            DSDivider()
                        }
                    }
                } else {
                    Text(L10n.BundleID.noProfiles)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.vertical, DS.spacingMD)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Capabilities

    private var enabledCapabilities: [CapabilityItem] {
        capabilities.filter(\.isEnabled)
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.enabledCaps) {
                DSBadge(text: L10n.count(enabledCapabilities.count), color: .dsTextSecondary)
            }

            DSGroupedCard {
                if isLoadingCaps {
                    loadingPlaceholder
                } else if enabledCapabilities.isEmpty {
                    Text(L10n.BundleID.noCaps)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.vertical, DS.spacingMD)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(enabledCapabilities) { cap in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.check)
                                .font(.caption)
                                .foregroundStyle(Color.dsGreen)
                                .frame(width: 28, height: 28)
                                .background(Color.dsAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                            Text(cap.name ?? cap.type)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsText)

                            Spacer()
                        }
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if cap.id != enabledCapabilities.last?.id {
                            DSDivider(leadingPadding: DS.spacingLG + 28 + DS.spacingMD)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        DSDangerButton(L10n.BundleID.deleteBundle, icon: AppIcon.close) {
            showDeleteConfirm = true
        }
    }

    // MARK: - Helpers

    private var loadingPlaceholder: some View {
        HStack {
            Spacer()
            ProgressView().controlSize(.small)
            Text(L10n.loading)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
        }
        .padding(.vertical, DS.spacingMD)
    }

    private func detailRow(_ label: String, value: String, monospaced: Bool = false, copyable: Bool = false) -> some View {
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

            if copyable {
                Button {
                    UIPasteboard.general.string = value
                    withAnimation { copiedText = value }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { if copiedText == value { copiedText = nil } }
                    }
                } label: {
                    HIcon(copiedText == value ? AppIcon.check : AppIcon.copy)
                        .font(.caption)
                        .foregroundStyle(copiedText == value ? .green : Color.dsTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DS.spacingSM)
    }

    private func loadCapabilities() async {
        isLoadingCaps = true
        do {
            capabilities = try await capService.list(bundleId: bundleId.id, accountId: accountId)
        } catch {
            AppLogger.data.error("Failed to load capabilities: \(error.localizedDescription)")
        }
        isLoadingCaps = false
    }

    private func loadResources() async {
        isLoadingResources = true
        do {
            resources = try await profileService.bundleIdResources(id: bundleId.id)
        } catch {
            AppLogger.data.error("Failed to load bundle ID resources: \(error.localizedDescription)")
        }
        isLoadingResources = false
    }
}
