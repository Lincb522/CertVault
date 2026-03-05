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
    @State private var appeared = false

    private let capService = CapabilityService()
    private let profileService = ProfileService()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingXL) {
                heroHeader
                    .staggeredAppear(index: 0, animate: appeared)
                infoCard
                    .staggeredAppear(index: 1, animate: appeared)
                devicesSection
                    .staggeredAppear(index: 2, animate: appeared)
                certificatesSection
                    .staggeredAppear(index: 3, animate: appeared)
                profilesSection
                    .staggeredAppear(index: 4, animate: appeared)
                capabilitiesSection
                    .staggeredAppear(index: 5, animate: appeared)
                deleteSection
                    .staggeredAppear(index: 6, animate: appeared)
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacingXL)
        }
        .pageBackground()
        .navigationTitle(L10n.BundleID.detail)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation { appeared = true } }
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

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.bundleID)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.dsGradientCyan, in: RoundedRectangle(cornerRadius: DS.radiusLG))

            Text(bundleId.displayName)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            if let platform = bundleId.platform {
                DSBadge(text: Localized.platform(platform), color: .dsBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingXL)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        DSGroupedCard {
            infoRow(L10n.BundleID.identifier, value: bundleId.identifier ?? L10n.na, mono: true, copyable: true)
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(NSLocalizedString("common.name", comment: ""), value: bundleId.name ?? L10n.na)
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(L10n.Cert.platform, value: Localized.platform(bundleId.platform ?? L10n.na))
            if let date = bundleId.created_at {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(L10n.Cert.createdAt, value: String(date.prefix(19)))
            }
        }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.relatedDevices) {
                Text(L10n.count(resources?.devices?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
            }

            DSGroupedCard {
                if isLoadingResources {
                    loadingPlaceholder
                } else if let devices = resources?.devices, !devices.isEmpty {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        NavigationLink {
                            DeviceDetailView(deviceId: device.id, accountId: accountId)
                        } label: {
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
                                    Text(device.udid ?? "")
                                        .font(.dsMonoSmall)
                                        .foregroundStyle(Color.dsTextSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let status = device.status {
                                    DSBadge.forStatus(status)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < devices.count - 1 {
                            DSDivider(leadingPadding: 60)
                        }
                    }
                } else {
                    Text(L10n.BundleID.noDevices)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Certificates

    private var certificatesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.relatedCerts) {
                Text(L10n.count(resources?.certificates?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
            }

            DSGroupedCard {
                if isLoadingResources {
                    loadingPlaceholder
                } else if let certs = resources?.certificates, !certs.isEmpty {
                    ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id, accountId: accountId)
                        } label: {
                            HStack(spacing: DS.spacingMD) {
                                HIcon(AppIcon.certificate)
                                    .font(.body)
                                    .foregroundStyle(Color.dsPurple)
                                    .frame(width: 36, height: 36)
                                    .background(Color.dsPurple.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusSM))

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
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < certs.count - 1 {
                            DSDivider(leadingPadding: 60)
                        }
                    }
                } else {
                    Text(L10n.BundleID.noCerts)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Profiles

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.relatedProfiles) {
                Text(L10n.count(resources?.profiles?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
            }

            DSGroupedCard {
                if isLoadingResources {
                    loadingPlaceholder
                } else if let profiles = resources?.profiles, !profiles.isEmpty {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.profile)
                                .font(.body)
                                .foregroundStyle(Color.dsOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.dsOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusSM))

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
                        .padding(.vertical, DS.spacingSM)
                        .padding(.horizontal, DS.spacingLG)

                        if index < profiles.count - 1 {
                            DSDivider(leadingPadding: 60)
                        }
                    }
                } else {
                    Text(L10n.BundleID.noProfiles)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Capabilities

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.BundleID.enabledCaps) {
                let enabledCount = capabilities.filter(\.isEnabled).count
                Text(L10n.count(enabledCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, DS.spacingSM)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceElevated, in: Capsule())
            }

            DSGroupedCard {
                if isLoadingCaps {
                    loadingPlaceholder
                } else {
                    let enabled = capabilities.filter(\.isEnabled)
                    if enabled.isEmpty {
                        Text(L10n.BundleID.noCaps)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                            .padding(DS.spacingLG)
                    } else {
                        ForEach(enabled) { cap in
                            HStack(spacing: DS.spacingMD) {
                                HIcon(AppIcon.check)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsGreen)
                                    .frame(width: 28, height: 28)
                                    .background(Color.dsGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusSM))

                                Text(cap.name ?? cap.type)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsText)

                                Spacer()
                            }
                            .padding(.vertical, DS.spacingSM)
                            .padding(.horizontal, DS.spacingLG)

                            if cap.id != enabled.last?.id {
                                DSDivider(leadingPadding: 60)
                            }
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

    private func infoRow(_ label: String, value: String, mono: Bool = false, copyable: Bool = false) -> some View {
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
                        .foregroundStyle(copiedText == value ? Color.dsGreen : Color.dsTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
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
