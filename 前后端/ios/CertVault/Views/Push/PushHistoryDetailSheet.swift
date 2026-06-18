import SwiftUI
import HiconIcons

struct PushHistoryDetailSheet: View {
    let itemId: Int
    @ObservedObject var vm: PushViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detail: PushHistoryItem?
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showResendConfirm = false
    @State private var resendToast: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if let detail {
                    ScrollView {
                        VStack(spacing: DS.Spacing.md) {
                            statusCard(detail)
                            infoCard(detail)
                            payloadCard(detail)
                            resendCard(detail)
                            if let errors = detail.errors, !errors.isEmpty {
                                errorsCard(errors)
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                } else {
                    ErrorView(message: errorMsg ?? "加载失败") {
                        Task { await loadDetail() }
                    }
                }
            }
            .navigationTitle("推送详情")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .alert("确认重发", isPresented: $showResendConfirm) {
                Button("重发", role: .destructive) {
                    Task {
                        await vm.resendHistory(id: itemId)
                        resendToast = vm.resendResult
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let d = detail {
                    Text("将以相同的标题和内容重新发送\(d.type == "broadcast" ? "广播推送" : "单设备推送")，确定继续吗？")
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = resendToast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(toast.contains("失败") ? Color.dsAccentPink : Color.dsAccent, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { resendToast = nil }
                            }
                        }
                }
            }
        }
        .sheetStyle()
        .task { await loadDetail() }
    }

    private func loadDetail() async {
        isLoading = true
        errorMsg = nil
        do {
            detail = try await vm.getHistoryDetail(id: itemId)
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Status Card

    private func statusCard(_ item: PushHistoryItem) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.forStatus(item.status).opacity(0.12))
                    .frame(width: 64, height: 64)
                HIcon(statusIcon(item.status))
                    .font(.title2)
                    .foregroundStyle(Color.forStatus(item.status))
            }

            Text(item.statusLabel)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.forStatus(item.status))

            InlineStatGrid(items: {
                var stats: [(String, Int, Color)] = [
                    ("目标", item.target_count?.value ?? 0, .dsAccentBlue),
                    ("成功", item.success_count?.value ?? 0, .dsAccent),
                ]
                if let f = item.failed_count, f.value > 0 {
                    stats.append(("失败", f.value, .dsAccentPink))
                }
                if let u = item.unregistered_count, u.value > 0 {
                    stats.append(("注销", u.value, .dsAccentOrange))
                }
                return stats
            }())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .glassTinted(Color.forStatus(item.status))
    }

    // MARK: - Info Card

    private func infoCard(_ item: PushHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionTitle(text: "推送信息", icon: AppIcon.info)

            VStack(spacing: DS.Spacing.sm) {
                InfoRow(label: "类型", value: item.type == "broadcast" ? "广播推送" : "单设备推送")
                InfoRow(label: "环境", value: item.sandbox == true ? "沙盒" : "生产")
                if let bid = item.bundle_id, !bid.isEmpty {
                    InfoRow(label: "Bundle", value: bid, monoValue: true)
                }
                if let d = item.duration_ms {
                    InfoRow(label: "耗时", value: "\(d.value) ms")
                }
                if let u = item.username, !u.isEmpty {
                    InfoRow(label: "操作人", value: u)
                }
                if let t = item.created_at {
                    InfoRow(label: "时间", value: formatDate(t))
                }
                if let apns = item.apns_id, !apns.isEmpty {
                    InfoRow(label: "APNs", value: apns, monoValue: true, selectable: true)
                }
                if let token = item.device_token, !token.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("设备 Token")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                        Text(token)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.dsText)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .glassCard(cornerRadius: DS.Radius.lg)
        }
    }

    // MARK: - Payload Card

    private func payloadCard(_ item: PushHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionTitle(text: "推送内容", icon: AppIcon.send)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if let title = item.title, !title.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("标题").font(.caption).foregroundStyle(Color.dsMuted)
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                    }
                }
                if let body = item.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("内容").font(.caption).foregroundStyle(Color.dsMuted)
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .glassCard(cornerRadius: DS.Radius.lg)
        }
    }

    // MARK: - Resend Card

    private func resendCard(_ item: PushHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionTitle(text: "操作", icon: AppIcon.send)

            Button {
                showResendConfirm = true
            } label: {
                HStack(spacing: 8) {
                    if vm.isResending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HIcon(AppIcon.send)
                            .font(.subheadline)
                    }
                    Text(item.type == "broadcast" ? "重发广播" : "重发推送")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.dsAccentBlue, .dsAccentPurple],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: DS.Radius.md)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isResending)
        }
    }

    // MARK: - Errors Card

    private func errorsCard(_ errors: [PushErrorItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionTitle(text: "错误详情", icon: AppIcon.warning, count: errors.count)

            VStack(spacing: 0) {
                ForEach(Array(errors.prefix(50).enumerated()), id: \.offset) { idx, err in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let reason = err.reason, !reason.isEmpty {
                                Text(reason)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsAccentPink)
                            }
                            Spacer()
                            if let status = err.status {
                                TypeBadge(text: "HTTP \(status)", color: .dsAccentPink)
                            }
                        }
                        if let errMsg = err.error, !errMsg.isEmpty {
                            Text(errMsg)
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }
                        if let token = err.token, !token.isEmpty {
                            Text(token.prefix(20) + "...")
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, DS.Spacing.md)

                    if idx < min(errors.count, 50) - 1 {
                        Divider().padding(.leading, DS.Spacing.md)
                    }
                }
            }
            .glassCard(cornerRadius: DS.Radius.lg)

            if errors.count > 50 {
                Text("仅显示前 50 条错误")
                    .font(.caption2)
                    .foregroundStyle(Color.dsMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private func statusIcon(_ status: String?) -> UIImage {
        switch status {
        case "success": return AppIcon.check
        case "partial": return AppIcon.warning
        case "failed": return AppIcon.close
        default: return AppIcon.info
        }
    }

    private func formatDate(_ str: String) -> String {
        str.toLocalDate()
    }
}
