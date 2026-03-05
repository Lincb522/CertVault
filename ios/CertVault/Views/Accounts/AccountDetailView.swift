import SwiftUI
import HiconIcons

struct AccountDetailView: View {
    let accountId: String
    @StateObject private var vm = AccountViewModel()
    @State private var showEditSheet = false
    @ObservedObject private var downloadService = FileDownloadService.shared

    var body: some View {
        Group {
            if let account = vm.selectedAccount {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        infoSection(account)
                        statsSection(account)
                        actionsSection(account)
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(id: accountId) }
            } else if vm.isLoading {
                LoadingView()
            } else if let err = vm.errorMessage {
                ErrorView(message: err) { await vm.loadDetail(id: accountId) }
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

    // MARK: - Info

    private func infoSection(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            HStack(spacing: DS.spacingMD) {
                HIcon(AppIcon.account)
                    .font(.title2)
                    .foregroundStyle(Color.dsBlue)
                    .frame(width: 48, height: 48)
                    .background(Color.dsBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusMD))

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Color.dsText)
                    if account.remote_synced == true {
                        DSBadge(text: L10n.Account.synced, color: .dsGreen)
                    }
                }
            }

            DSDivider(leadingPadding: 0)

            Group {
                DetailInfoRow(label: "Issuer ID", value: account.issuer_id ?? "N/A")
                DetailInfoRow(label: "Key ID", value: account.key_id ?? "N/A")
                if let date = account.created_at {
                    DetailInfoRow(label: L10n.Cert.createdAt, value: String(date.prefix(19)))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Stats

    private func statsSection(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(NSLocalizedString("account.stats", comment: ""))

            if let stats = account.stats {
                LazyVGrid(columns: [.init(.flexible(), spacing: DS.spacingSM), .init(.flexible(), spacing: DS.spacingSM)], spacing: DS.spacingSM) {
                    MiniStatCard(icon: AppIcon.certificate, title: NSLocalizedString("account.stat.certs", comment: ""), value: "\(stats.certificates ?? 0)", color: .dsPurple)
                    MiniStatCard(icon: AppIcon.device, title: NSLocalizedString("account.stat.devices", comment: ""), value: "\(stats.devices ?? 0)", color: .dsGreen)
                    MiniStatCard(icon: AppIcon.bundleID, title: "Bundle ID", value: "\(stats.bundle_ids ?? 0)", color: .dsCyan)
                    MiniStatCard(icon: AppIcon.profile, title: NSLocalizedString("account.stat.profiles", comment: ""), value: "\(stats.profiles ?? 0)", color: .dsOrange)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(_ account: Account) -> some View {
        VStack(spacing: DS.spacingSM) {
            Button {
                Task { await vm.testConnection(id: accountId) }
            } label: {
                HStack(spacing: DS.spacingSM) {
                    if vm.isTesting {
                        ProgressView().tint(.white)
                    } else {
                        HIcon(AppIcon.wifi).font(.body)
                    }
                    Text(L10n.Account.testConnection)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
            }
            .disabled(vm.isTesting)

            if let result = vm.testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("成功") ? Color.dsGreen : Color.dsDanger)
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
                .padding(.vertical, 13)
                .foregroundStyle(Color.dsBlue)
                .background(Color.dsBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusMD))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusMD)
                        .stroke(Color.dsBlue.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Detail Info Row

private struct DetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(Color.dsText)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Mini Stat Card

private struct MiniStatCard: View {
    let icon: UIImage
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.spacingSM) {
            HIcon(icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Spacer()
        }
        .padding(DS.spacingMD)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMD)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }
}
