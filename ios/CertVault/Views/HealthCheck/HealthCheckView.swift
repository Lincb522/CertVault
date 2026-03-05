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
        DSGroupedCard {
            if vm.accounts.isEmpty {
                HStack(spacing: DS.spacingMD) {
                    HIcon(AppIcon.warning)
                        .foregroundStyle(Color.dsOrange)
                    Text(L10n.HealthCheck.addAccount)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                    Spacer()
                }
                .padding(.vertical, DS.spacingMD)
                .padding(.horizontal, DS.spacingLG)
            } else {
                HStack {
                    Text(L10n.account)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
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

    // MARK: - Start

    private var startButton: some View {
        DSPrimaryButton(
            title: L10n.HealthCheck.startCheck,
            isLoading: isLoading,
            isDisabled: checkMode == 1 && vm.selectedAccountId.isEmpty
        ) {
            Task {
                if checkMode == 0 {
                    await vm.runLocalCheck()
                } else {
                    await vm.runRemoteCheck()
                }
            }
        }
    }

    // MARK: - Summary

    private func summarySection(_ result: HealthCheckResult) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.HealthCheck.summary)

            if let summary = result.summary {
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: DS.spacingSM), count: 4), spacing: DS.spacingSM) {
                    SummaryBadge(label: NSLocalizedString("health.critical", comment: ""), count: summary.critical ?? 0, gradient: Color.dsGradientPink)
                    SummaryBadge(label: NSLocalizedString("health.warning", comment: ""), count: summary.warning ?? 0, gradient: Color.dsGradientOrange)
                    SummaryBadge(label: NSLocalizedString("health.info", comment: ""), count: summary.info ?? 0, gradient: Color.dsGradientBlue)
                    SummaryBadge(label: NSLocalizedString("health.ok", comment: ""), count: summary.ok ?? 0, gradient: Color.dsGradientGreen)
                }
            }
        }
    }

    // MARK: - Issues

    private func issuesSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let issues = result.issues, !issues.isEmpty {
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    DSSectionHeader(L10n.HealthCheck.issues)
                    DSGroupedCard {
                        ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                            HStack(alignment: .top, spacing: DS.spacingMD) {
                                HIcon(iconForLevel(issue.level ?? "info"))
                                    .foregroundStyle(colorForLevel(issue.level ?? "info"))
                                    .frame(width: 20)
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
                            .padding(.vertical, DS.spacingSM)
                            .padding(.horizontal, DS.spacingLG)

                            if index < issues.count - 1 {
                                DSDivider(leadingPadding: 46)
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
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    DSSectionHeader(L10n.HealthCheck.certStatus)
                    DSGroupedCard {
                        ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.name ?? L10n.unnamed)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.certType(cert.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                                Spacer()
                                if let expires = cert.expires_at {
                                    Text(String(expires.prefix(10)))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Color.dsTextTertiary)
                                }
                                certStatusBadge(cert)
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
        }
    }

    private func certStatusBadge(_ cert: HealthCertInfo) -> some View {
        let text = cert.label ?? cert.status ?? L10n.unknown
        let color: Color = {
            if let days = cert.days_left {
                if days < 0 { return .dsPink }
                if days <= 30 { return .dsOrange }
                return .dsGreen
            }
            return DSBadge.forStatus(cert.status ?? "UNKNOWN").color
        }()
        return DSBadge(text: text, color: color)
    }

    // MARK: - Profiles

    private func profilesSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let profiles = result.profiles, !profiles.isEmpty {
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    DSSectionHeader(L10n.HealthCheck.profileStatus)
                    DSGroupedCard {
                        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
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
                                profileStatusBadge(profile)
                            }
                            .padding(.vertical, DS.spacingSM)
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
                if days < 0 { return .dsPink }
                if days <= 30 { return .dsOrange }
                return .dsGreen
            }
            return DSBadge.forStatus(profile.status ?? "UNKNOWN").color
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
        case "warning": return .dsOrange
        case "info": return .dsBlue
        default: return .dsGreen
        }
    }
}

// MARK: - Summary Badge

private struct SummaryBadge: View {
    let label: String
    let count: Int
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? .white : Color.dsTextSecondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(count > 0 ? .white.opacity(0.85) : Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingSM)
        .background {
            if count > 0 {
                RoundedRectangle(cornerRadius: DS.radiusSM)
                    .fill(gradient)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: DS.radiusSM)
                    .fill(Color.dsSurface)
                    .overlay(RoundedRectangle(cornerRadius: DS.radiusSM).stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5))
            }
        }
    }
}
