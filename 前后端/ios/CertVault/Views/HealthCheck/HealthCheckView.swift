import SwiftUI
import HiconIcons

struct HealthCheckView: View {
    @StateObject private var vm = HealthCheckViewModel()
    @State private var checkMode = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                modeSelector
                    .padding(.horizontal, 16)

                if checkMode == 1 {
                    accountSelector
                        .padding(.horizontal, 16)
                }

                startButton
                    .padding(.horizontal, 16)

                if let result = currentResult {
                    summarySection(result)
                        .padding(.horizontal, 16)
                    issuesSection(result)
                        .padding(.horizontal, 16)
                    certsSection(result)
                        .padding(.horizontal, 16)
                    profilesSection(result)
                        .padding(.horizontal, 16)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color.dsAccentPink)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle(L10n.HealthCheck.title)
        .task { await vm.loadAccounts() }
    }

    private var isLoading: Bool {
        checkMode == 0 ? vm.isLoadingLocal : vm.isLoadingRemote
    }

    private var canStartCheck: Bool {
        !isLoading && !(checkMode == 1 && vm.selectedAccountId.isEmpty)
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
        VStack(alignment: .leading, spacing: 8) {
            if vm.accounts.isEmpty {
                HStack {
                    HIcon(AppIcon.warning)
                        .foregroundStyle(Color.dsAccentOrange)
                    Text(L10n.HealthCheck.addAccount)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12)
            } else {
                HStack {
                    Text(L10n.account)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                    Spacer()
                    Picker("", selection: $vm.selectedAccountId) {
                        ForEach(vm.accounts) { acc in
                            Text(acc.displayName).tag(acc.id)
                        }
                    }
                    .tint(Color.dsAccentBlue)
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Button {
            Task {
                if checkMode == 0 {
                    await vm.runLocalCheck()
                } else {
                    await vm.runRemoteCheck()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HIcon(AppIcon.health).font(.body)
                }
                Text(L10n.HealthCheck.startCheck)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(canStartCheck ? Color.white : Color.dsMuted)
            .background(
                canStartCheck ? Color.dsAccentBlue : Color.dsSurfaceLight,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canStartCheck)
    }

    // MARK: - Summary

    private func summarySection(_ result: HealthCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.HealthCheck.summary)

            if let summary = result.summary {
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    SummaryBadge(label: NSLocalizedString("health.critical", comment: ""), count: summary.critical ?? 0, color: .dsAccentPink)
                    SummaryBadge(label: NSLocalizedString("health.warning", comment: ""), count: summary.warning ?? 0, color: .dsAccentOrange)
                    SummaryBadge(label: NSLocalizedString("health.info", comment: ""), count: summary.info ?? 0, color: .dsAccentBlue)
                    SummaryBadge(label: NSLocalizedString("health.ok", comment: ""), count: summary.ok ?? 0, color: .dsAccent)
                }
            }
        }
    }

    // MARK: - Issues

    private func issuesSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let issues = result.issues, !issues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L10n.HealthCheck.issues)

                    VStack(spacing: 0) {
                        ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                            HStack(alignment: .top, spacing: 12) {
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
                                            .foregroundStyle(Color.dsMuted)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < issues.count - 1 {
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                    .glassCard(cornerRadius: 12)
                }
            }
        }
    }

    // MARK: - Certs

    private func certsSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let certs = result.certificates, !certs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L10n.HealthCheck.certStatus)

                    VStack(spacing: 0) {
                        ForEach(Array(certs.enumerated()), id: \.element.id) { index, cert in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cert.name ?? L10n.unnamed)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.certType(cert.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsMuted)
                                }
                                Spacer()
                                if let expires = cert.expires_at {
                                    Text(expires.toLocalDate(.short))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(Color.dsMuted.opacity(0.6))
                                }
                                certStatusBadge(cert)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < certs.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .glassCard(cornerRadius: 12)
                }
            }
        }
    }

    private func certStatusBadge(_ cert: HealthCertInfo) -> some View {
        let text = cert.label ?? cert.status ?? L10n.unknown
        let color: Color = {
            if let days = cert.days_left {
                if days < 0 { return .dsAccentPink }
                if days <= 30 { return .dsAccentOrange }
                return .dsAccent
            }
            return StatusBadge.forStatus(cert.status ?? "UNKNOWN").color
        }()
        return StatusBadge(text, color: color)
    }

    // MARK: - Profiles

    private func profilesSection(_ result: HealthCheckResult) -> some View {
        Group {
            if let profiles = result.profiles, !profiles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L10n.HealthCheck.profileStatus)

                    VStack(spacing: 0) {
                        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name ?? L10n.unnamed)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsText)
                                    Text(Localized.profileType(profile.type ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(Color.dsMuted)
                                }
                                Spacer()
                                profileStatusBadge(profile)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)

                            if index < profiles.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .glassCard(cornerRadius: 12)
                }
            }
        }
    }

    private func profileStatusBadge(_ profile: HealthProfileInfo) -> some View {
        let text = profile.label ?? profile.state ?? profile.status ?? L10n.unknown
        let color: Color = {
            if let days = profile.days_left {
                if days < 0 { return .dsAccentPink }
                if days <= 30 { return .dsAccentOrange }
                return .dsAccent
            }
            return StatusBadge.forStatus(profile.status ?? "UNKNOWN").color
        }()
        return StatusBadge(text, color: color)
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
        case "critical": return .dsAccentPink
        case "warning": return .dsAccentOrange
        case "info": return .dsAccentBlue
        default: return .dsAccent
        }
    }
}

// MARK: - Summary Badge

private struct SummaryBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : Color.dsMuted)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            (count > 0 ? color.opacity(0.1) : Color.dsSurface),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(count > 0 ? color.opacity(0.2) : Color.dsBorder, lineWidth: 1)
        )
    }
}
