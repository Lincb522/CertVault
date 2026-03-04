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
                    VStack(spacing: 20) {
                        infoSection(account)
                        statsSection(account)
                        actionsSection(account)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(id: accountId) }
            } else if vm.isLoading {
                LoadingView()
            } else if let err = vm.errorMessage {
                ErrorView(message: err) { Task { await vm.loadDetail(id: accountId) } }
            } else {
                LoadingView()
            }
        }
        .navigationTitle("账号详情")
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HIcon(AppIcon.account)
                    .font(.title2)
                    .foregroundStyle(Color.dsAccentBlue)
                    .frame(width: 48, height: 48)
                    .background(Color.dsAccentBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Color.dsText)
                    if account.remote_synced == true {
                        StatusBadge("已同步", color: .dsAccent)
                    }
                }
            }

            Divider().overlay(Color.dsBorder)

            Group {
                InfoRow(label: "Issuer ID", value: account.issuer_id ?? "N/A")
                InfoRow(label: "Key ID", value: account.key_id ?? "N/A")
                if let date = account.created_at {
                    InfoRow(label: "创建时间", value: String(date.prefix(19)))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Stats

    private func statsSection(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("资源统计")

            if let stats = account.stats {
                LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                    MiniStatCard(icon: AppIcon.certificate, title: "证书", value: "\(stats.certificates ?? 0)", color: .dsAccentPurple)
                    MiniStatCard(icon: AppIcon.device, title: "设备", value: "\(stats.devices ?? 0)", color: .dsAccent)
                    MiniStatCard(icon: AppIcon.bundleID, title: "Bundle ID", value: "\(stats.bundle_ids ?? 0)", color: .dsAccentCyan)
                    MiniStatCard(icon: AppIcon.profile, title: "描述文件", value: "\(stats.profiles ?? 0)", color: .dsAccentOrange)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionsSection(_ account: Account) -> some View {
        VStack(spacing: 10) {
            Button {
                Task { await vm.testConnection(id: accountId) }
            } label: {
                HStack(spacing: 8) {
                    if vm.isTesting {
                        ProgressView().tint(.white)
                    } else {
                        HIcon(AppIcon.wifi).font(.body)
                    }
                    Text("测试连接")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.isTesting)

            if let result = vm.testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("成功") ? Color.dsAccent : Color.dsAccentPink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            Button {
                Task { await downloadService.download(endpoint: "/accounts/\(accountId)/download-p8") }
            } label: {
                HStack(spacing: 8) {
                    HIcon(AppIcon.docDownload).font(.body)
                    Text("下载 P8 文件")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(Color.dsAccentBlue)
                .background(Color.dsAccentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dsAccentBlue.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Shared Detail Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
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
        HStack(spacing: 10) {
            HIcon(icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }
}
