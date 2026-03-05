import SwiftUI
import HiconIcons

struct AccountDetailView: View {
    let accountId: String
    @StateObject private var vm = AccountViewModel()
    @State private var showEditSheet = false
    @State private var appeared = false
    @ObservedObject private var downloadService = FileDownloadService.shared

    var body: some View {
        Group {
            if let account = vm.selectedAccount {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        heroHeader(account)
                            .staggeredAppear(index: 0, animate: appeared)
                        infoSection(account)
                            .staggeredAppear(index: 1, animate: appeared)
                        statsSection(account)
                            .staggeredAppear(index: 2, animate: appeared)
                        actionsSection(account)
                            .staggeredAppear(index: 3, animate: appeared)
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(id: accountId) }
                .onAppear { withAnimation { appeared = true } }
            } else if vm.isLoading {
                LoadingView()
            } else if let err = vm.errorMessage {
                ErrorView(message: err) { Task { await vm.loadDetail(id: accountId) } }
            } else {
                LoadingView()
            }
        }
        .navigationTitle(L10n.Account.detail)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.selectedAccount != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { showEditSheet = true } label: {
                        HIcon(AppIcon.edit)
                    }
                }
            }
        }
        .task { await vm.loadDetail(id: accountId) }
        .sheet(isPresented: $showEditSheet) {
            if let account = vm.selectedAccount {
                AccountFormView(vm: vm, mode: .edit(account))
            }
        }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Hero Header

    private func heroHeader(_ account: Account) -> some View {
        VStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.account)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.dsGradientBlue, in: RoundedRectangle(cornerRadius: DS.radiusLG))

            Text(account.displayName)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            if account.remote_synced == true {
                DSBadge(text: L10n.Account.synced, color: .dsGreen)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingXL)
    }

    // MARK: - Info

    private func infoSection(_ account: Account) -> some View {
        DSGroupedCard {
            infoRow(label: "Issuer ID", value: account.issuer_id ?? "N/A")
            DSDivider(leadingPadding: DS.spacingLG)
            infoRow(label: "Key ID", value: account.key_id ?? "N/A")
            if let date = account.created_at {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: L10n.Cert.createdAt, value: String(date.prefix(19)))
            }
        }
    }

    // MARK: - Stats

    private func statsSection(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(NSLocalizedString("account.stats", comment: ""))

            if let stats = account.stats {
                LazyVGrid(columns: [.init(.flexible(), spacing: DS.spacingSM), .init(.flexible(), spacing: DS.spacingSM)], spacing: DS.spacingSM) {
                    DSStatCard(title: NSLocalizedString("account.stat.certs", comment: ""), value: "\(stats.certificates ?? 0)", icon: AppIcon.certificate, gradient: .dsGradientPurple)
                    DSStatCard(title: NSLocalizedString("account.stat.devices", comment: ""), value: "\(stats.devices ?? 0)", icon: AppIcon.device, gradient: .dsGradientGreen)
                    DSStatCard(title: "Bundle ID", value: "\(stats.bundle_ids ?? 0)", icon: AppIcon.bundleID, gradient: .dsGradientCyan)
                    DSStatCard(title: NSLocalizedString("account.stat.profiles", comment: ""), value: "\(stats.profiles ?? 0)", icon: AppIcon.profile, gradient: .dsGradientOrange)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(_ account: Account) -> some View {
        VStack(spacing: DS.spacingMD) {
            DSPrimaryButton(
                title: L10n.Account.testConnection,
                isLoading: vm.isTesting
            ) {
                Task { await vm.testConnection(id: accountId) }
            }

            if let result = vm.testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("成功") ? Color.dsGreen : Color.dsPink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.spacingXS)
            }

            Button {
                Task { await downloadService.download(endpoint: "/accounts/\(accountId)/download-p8") }
            } label: {
                HStack(spacing: DS.spacingSM) {
                    HIcon(AppIcon.docDownload).font(.body)
                    Text(L10n.Account.downloadP8)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.dsBlue)
                .background(Color.dsBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusMD))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusMD)
                        .stroke(Color.dsBlue.opacity(0.2), lineWidth: 1)
                )
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
                .font(.dsMono)
                .foregroundStyle(Color.dsText)
                .textSelection(.enabled)
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
    }
}
