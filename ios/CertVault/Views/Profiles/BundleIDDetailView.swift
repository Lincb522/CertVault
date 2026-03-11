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
            VStack(spacing: 20) {
                infoCard
                devicesSection
                certificatesSection
                profilesSection
                capabilitiesSection
                deleteSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HIcon(AppIcon.bundleID)
                    .font(.title2)
                    .foregroundStyle(Color.dsAccentCyan)
                    .frame(width: 48, height: 48)
                    .background(Color.dsAccentCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(bundleId.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Color.dsText)
                    if let platform = bundleId.platform {
                        StatusBadge(platform, color: .dsAccentBlue)
                    }
                }
            }

            Divider().overlay(Color.dsBorder)

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.device)
                    .foregroundStyle(Color.dsAccent)
                Text(L10n.BundleID.relatedDevices)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.count(resources?.devices?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if isLoadingResources {
                loadingPlaceholder
            } else if let devices = resources?.devices, !devices.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                        NavigationLink {
                            DeviceDetailView(deviceId: device.id, accountId: accountId)
                        } label: {
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
                                    Text(device.udid ?? "")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Color.dsMuted)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let status = device.status {
                                    StatusBadge.forStatus(status)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)

                        if index < devices.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            } else {
                Text(L10n.BundleID.noDevices)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }

    // MARK: - Certificates

    private var certificatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.certificate)
                    .foregroundStyle(Color.dsAccentPurple)
                Text(L10n.BundleID.relatedCerts)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.count(resources?.certificates?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if isLoadingResources {
                loadingPlaceholder
            } else if let certs = resources?.certificates, !certs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id, accountId: accountId)
                        } label: {
                            HStack(spacing: 12) {
                                HIcon(AppIcon.certificate)
                                    .font(.body)
                                    .foregroundStyle(Color.dsAccentPurple)
                                    .frame(width: 36, height: 36)
                                    .background(Color.dsAccentPurple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    HStack(spacing: 6) {
                                        Text(Localized.certType(cert.type ?? ""))
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
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)

                        if index < certs.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            } else {
                Text(L10n.BundleID.noCerts)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }

    // MARK: - Profiles

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.profile)
                    .foregroundStyle(Color.dsAccentOrange)
                Text(L10n.BundleID.relatedProfiles)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()
                Text(L10n.count(resources?.profiles?.count ?? 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if isLoadingResources {
                loadingPlaceholder
            } else if let profiles = resources?.profiles, !profiles.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        HStack(spacing: 12) {
                            HIcon(AppIcon.profile)
                                .font(.body)
                                .foregroundStyle(Color.dsAccentOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.dsAccentOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
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
                        .padding(.vertical, 10)

                        if index < profiles.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            } else {
                Text(L10n.BundleID.noProfiles)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .padding(.vertical, 8)
            }
        }
        .cardStyle()
    }

    // MARK: - Capabilities

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HIcon(AppIcon.star)
                    .foregroundStyle(Color.dsAccentOrange)
                Text(L10n.BundleID.enabledCaps)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Spacer()

                let enabledCount = capabilities.filter(\.isEnabled).count
                Text(L10n.count(enabledCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dsMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dsSurfaceLight, in: Capsule())
            }

            if isLoadingCaps {
                loadingPlaceholder
            } else {
                let enabled = capabilities.filter(\.isEnabled)
                if enabled.isEmpty {
                    Text(L10n.BundleID.noCaps)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(enabled) { cap in
                            HStack(spacing: 12) {
                                HIcon(AppIcon.check)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsAccent)
                                    .frame(width: 28, height: 28)
                                    .background(Color.dsAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                                Text(cap.name ?? cap.type)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsText)

                                Spacer()
                            }
                            .padding(.vertical, 8)

                            if cap.id != enabled.last?.id {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                HIcon(AppIcon.close).font(.body)
                Text(L10n.BundleID.deleteBundle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.dsAccentPink, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private var loadingPlaceholder: some View {
        HStack {
            Spacer()
            ProgressView().controlSize(.small)
            Text(L10n.loading)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private func detailRow(_ label: String, value: String, monospaced: Bool = false, copyable: Bool = false) -> some View {
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
                        .foregroundStyle(copiedText == value ? .green : Color.dsMuted)
                }
                .buttonStyle(.plain)
            }
        }
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
