import SwiftUI
import HiconIcons

struct HealthCheckView: View {
    @StateObject private var vm = HealthCheckViewModel()
    @State private var checkMode = 0

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingLG) {
                modeSelector
                    .padding(.horizontal, DS.spacingLG)

                if checkMode == 1 {
                    accountSelector
                        .padding(.horizontal, DS.spacingLG)
                }

                startButton
                    .padding(.horizontal, DS.spacingLG)

                if let result = currentResult {
                    summarySection(result)
                        .padding(.horizontal, DS.spacingLG)
                    issuesSection(result)
                        .padding(.horizontal, DS.spacingLG)
                    certsSection(result)
                        .padding(.horizontal, DS.spacingLG)
                    profilesSection(result)
                        .padding(.horizontal, DS.spacingLG)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color.dsDanger)
                        .padding(.horizontal, DS.spacingLG)
                }
            }
            .padding(.top, DS.spacingSM)
            .padding(.bottom, DS.spacingXL)
        }
        .pageBackground()
        .navigationTitle(L10n.HealthCheck.title)
        .task { await vm.loadAccounts() }
    }

    private var isLoading: Bool {
        checkMode == 0 ? vm.isLoadingLocal : vm.isLoadingRemote
    }

    private var currentResult: HealthCheckResult? {
        checkMode == 0 ? vm.localResult : vm.remoteResult
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        Picker("", selection: $checkMode) {
            Text(L10n.HealthCheck.localCheck).tag(0)
            Text(L10n.HealthCheck.remoteCheck).tag(1)
        }
        .pickerStyle(.segmented)
    }

    private var accountSelector: some View {
        Group {
            if vm.accounts.isEmpty {
                HStack(spacing: DS.spacingMD) {
                    HIcon(AppIcon.warning)
                        .font(.callout)
                        .foregroundStyle(Color.dsWarning)
                    Text(L10n.HealthCheck.addAccount)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .padding(DS.spacingLG)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusLG))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusLG)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
            } else {
                DSGroupedCard {
                    HStack {
                        Text(L10n.account)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                        Spacer()
                        Picker("", selection: $vm.selectedAccountId) {
                            ForEach(vm.accounts) { acc in
                                Text(acc.displayName).tag(acc.id)
                            }
                        }
                        .tint(Color.dsBrand)
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                }
            }
        }
    }

    // MARK: - Start

    private var startButton: some View {
        DSPrimaryButton(
            title: L10n.HealthCheck.startCheck,
            isLoading: isLoading,
            isDisabled: isLoading || (checkMode == 1 && vm.selectedAccountId.isEmpty)
        ) {
            if checkMode == 0 {
                Task { await vm.runLocalCheck() }
            } else {
                Task { await vm.runRemoteCheck() }
            }
        }
    }

    // MARK: - Summary

    private func summarySection(_ result: HealthCheckResult) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.HealthCheck.summary)

            if let summary = result.summary {
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: DS.spacingMD), count: 4), spacing: DS.spacingMD) {
                    SummaryBadge(label: NSLocalizedString("health.critical", comment: ""), count: summary.critical ?? 0, color: .dsDanger)
                    SummaryBadge(label: NSLocalizedString("health.warning", comment: ""), count: summary.warning ?? 0, color: .dsWarning)
                    SummaryBadge(label: NSLocalizedString("health.info", comment: ""), count: summary.info ?? 0, color: .dsBlue)
                    SummaryBadge(label: NSLocalizedString("health.ok", comment: ""), count: summary.ok ?? 0, color: .dsSuccess)
                }
            }
        }
    }

    // MARK: - Issues

    private func issuesSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let issues = result.issues, !issues.isEmpty {
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    DSSectionHeader(L10n.HealthCheck.issues)

                    DSGroupedCard {
                        ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                            HStack(alignment: .top, spacing: DS.spacingMD) {
                                HIcon(iconForLevel(issue.level ?? "info"))
                                    .font(.callout)
                                    .foregroundStyle(colorForLevel(issue.level ?? "info"))
                                    .frame(width: DS.iconMD)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.message ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsText)
                                    if let detail = issue.detail {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundStyle(Color.dsTextSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, DS.spacingMD)
                            .padding(.horizontal, DS.spacingLG)

                            if index < issues.count - 1 {
                                DSDivider(leadingPadding: DS.spacingLG + DS.iconMD)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Certs

    private func certsSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let certs = result.certificates, !certs.isEmpty {
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    DSSectionHeader(L10n.HealthCheck.certStatus)

                    DSGroupedCard {
                        ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.name ?? L10n.unnamed)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.certType(cert.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                                Spacer()
                                if let expires = cert.expires_at {
                                    Text(String(expires.prefix(10)))
                                        .font(.dsMonoSmall)
                                        .foregroundStyle(Color.dsTextTertiary)
                                }
                                certStatusBadge(cert)
                            }
                            .padding(.vertical, DS.spacingMD)
                            .padding(.horizontal, DS.spacingLG)

                            if index < certs.count - 1 {
                                DSDivider(leadingPadding: DS.spacingLG)
                            }
                        }
                    }
                }
            }
        }
    }

    private func certStatusBadge(_ cert: HealthCertInfo) -> some View {
        let text = cert.label ?? cert.status ?? L10n.unknown
        let color: Color = {
            if let days = cert.days_left {
                if days < 0 { return .dsDanger }
                if days <= 30 { return .dsWarning }
                return .dsSuccess
            }
            return colorForCertStatus(cert.status ?? "UNKNOWN")
        }()
        return DSBadge(text: text, color: color)
    }

    private func colorForCertStatus(_ status: String) -> Color {
        switch status.uppercased() {
        case "ACTIVE", "VALID", "ENABLED", "ONLINE": return .dsSuccess
        case "EXPIRED", "REVOKED", "INVALID", "DISABLED", "OFFLINE": return .dsDanger
        case "PENDING", "PROCESSING": return .dsWarning
        default: return .dsTextSecondary
        }
    }

    // MARK: - Profiles

    private func profilesSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let profiles = result.profiles, !profiles.isEmpty {
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    DSSectionHeader(L10n.HealthCheck.profileStatus)

                    DSGroupedCard {
                        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name ?? L10n.unnamed)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.profileType(profile.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                                Spacer()
                                profileStatusBadge(profile)
                            }
                            .padding(.vertical, DS.spacingMD)
                            .padding(.horizontal, DS.spacingLG)

                            if index < profiles.count - 1 {
                                DSDivider(leadingPadding: DS.spacingLG)
                            }
                        }
                    }
                }
            }
        }
    }

    private func profileStatusBadge(_ profile: HealthProfileInfo) -> some View {
        let text = profile.label ?? profile.state ?? profile.status ?? L10n.unknown
        let color: Color = {
            if let days = profile.days_left {
                if days < 0 { return .dsDanger }
                if days <= 30 { return .dsWarning }
                return .dsSuccess
            }
            return colorForCertStatus(profile.status ?? "UNKNOWN")
        }()
        return DSBadge(text: text, color: color)
    }

    // MARK: - Helpers

    private func iconForLevel(_ level: String) -> UIImage {
        switch level.lowercased() {
        case "critical": return AppIcon.close
        case "warning": return AppIcon.warning
        case "info": return AppIcon.info
        default: return AppIcon.check
        }
    }

    private func colorForLevel(_ level: String) -> Color {
        switch level.lowercased() {
        case "critical": return .dsDanger
        case "warning": return .dsWarning
        case "info": return .dsBlue
        default: return .dsSuccess
        }
    }
}

// MARK: - Summary Badge

private struct SummaryBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : Color.dsTextSecondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingMD)
        .background(
            (count > 0 ? color.opacity(0.1) : Color.dsSurface),
            in: RoundedRectangle(cornerRadius: DS.radiusMD)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMD)
                .stroke(count > 0 ? color.opacity(0.2) : Color.dsBorder, lineWidth: 1)
        )
    }
}
