import SwiftUI
import HiconIcons

struct PushHistoryView: View {
    @StateObject private var vm = PushViewModel()
    @State private var filterType: String?
    @State private var filterStatus: String?
    @State private var showClearAlert = false
    @State private var selectedItemId: Int?
    @State private var animateContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                statsSection
                    .staggeredAnimation(index: 0, trigger: animateContent)

                filterSection
                    .staggeredAnimation(index: 1, trigger: animateContent)

                historyListSection
                    .staggeredAnimation(index: 2, trigger: animateContent)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
        .pageBackground()
        .navigationTitle("推送历史")
        .refreshable { await reload() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { showClearAlert = true } label: {
                        Label("清空历史", systemImage: "trash")
                    }
                } label: {
                    HIcon(AppIcon.moreCircle)
                }
            }
        }
        .alert("确认清空", isPresented: $showClearAlert) {
            Button("清空全部", role: .destructive) {
                Task { try? await vm.clearHistory() }
            }
            Button("仅清空30天前", role: .destructive) {
                Task { try? await vm.clearHistory(beforeDays: 30) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后无法恢复，确定要继续吗？")
        }
        .task {
            await reload()
            withAnimation(DS.Animation.normal) { animateContent = true }
        }
        .sheet(isPresented: Binding(
            get: { selectedItemId != nil },
            set: { if !$0 { selectedItemId = nil } }
        )) {
            if let id = selectedItemId {
                PushHistoryDetailSheet(itemId: id, vm: vm)
            }
        }
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        if let stats = vm.historyStats {
            VStack(spacing: DS.Spacing.sm) {
                InlineStatGrid(items: [
                    ("总推送", stats.total_pushes?.value ?? 0, .dsAccentBlue),
                    ("今日", stats.today_pushes?.value ?? 0, .dsAccentPurple),
                    ("已送达", stats.total_delivered?.value ?? 0, .dsAccent),
                    ("失败", stats.total_failed?.value ?? 0, .dsAccentPink),
                ])

                HStack(spacing: DS.Spacing.sm) {
                    StatPill(label: "单推", value: "\(stats.singles?.value ?? 0)", color: .dsAccentCyan)
                    StatPill(label: "广播", value: "\(stats.broadcasts?.value ?? 0)", color: .dsAccentOrange)
                    Spacer()
                    Text("共 \(vm.historyTotal) 条")
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                }
            }
        }
    }

    // MARK: - Filters

    private var filterSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Menu {
                Button("全部") { filterType = nil }
                Button("单推") { filterType = "single" }
                Button("广播") { filterType = "broadcast" }
            } label: {
                filterLabel("类型", value: filterType == nil ? "全部" : (filterType == "broadcast" ? "广播" : "单推"), color: .dsAccentBlue)
            }

            Menu {
                Button("全部") { filterStatus = nil }
                Button("成功") { filterStatus = "success" }
                Button("部分成功") { filterStatus = "partial" }
                Button("失败") { filterStatus = "failed" }
            } label: {
                filterLabel("状态", value: filterStatus ?? "全部", color: .dsAccentPurple)
            }

            Spacer()
        }
        .onChange(of: filterType) { Task { await reload() } }
        .onChange(of: filterStatus) { Task { await reload() } }
    }

    private func filterLabel(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(title): \(value)")
                .font(.caption.weight(.medium))
            HIcon(AppIcon.down)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.08), in: Capsule())
    }

    // MARK: - History List

    private var historyListSection: some View {
        VStack(spacing: 0) {
            if vm.isLoading && vm.historyItems.isEmpty {
                LoadingView()
                    .frame(minHeight: 200)
            } else if vm.historyItems.isEmpty {
                EmptyStateView(
                    icon: AppIcon.bellSlash,
                    title: "暂无推送记录",
                    message: "发送推送后将在此显示历史记录"
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.historyItems.enumerated()), id: \.element.stableId) { index, item in
                        Button { selectedItemId = item.id } label: {
                            historyRow(item)
                        }
                        .buttonStyle(.plain)

                        if index < vm.historyItems.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .glassCard(cornerRadius: DS.Radius.lg)

                if vm.historyItems.count < vm.historyTotal {
                    Button {
                        Task { await vm.loadHistory(page: vm.historyPage + 1, type: filterType, status: filterStatus) }
                    } label: {
                        HStack(spacing: 6) {
                            HIcon(AppIcon.down).font(.caption)
                            Text("加载更多")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsAccentBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.top, DS.Spacing.sm)
                    .glassCard(cornerRadius: DS.Radius.md)
                }
            }
        }
    }

    // MARK: - Row

    private func historyRow(_ item: PushHistoryItem) -> some View {
        HStack(spacing: 12) {
            statusIcon(item.status)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    TypeBadge(
                        text: item.typeLabel,
                        color: item.type == "broadcast" ? .dsAccentOrange : .dsAccentBlue
                    )
                    StatusBadge(item.statusLabel, color: Color.forStatus(item.status))
                    Spacer()
                    Text((item.created_at ?? "").toLocalDate())
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }

                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
                        .lineLimit(1)
                }

                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    if let t = item.target_count { MetaLabel(label: "目标", value: "\(t.value)") }
                    if let s = item.success_count { MetaLabel(label: "成功", value: "\(s.value)") }
                    if let f = item.failed_count, f.value > 0 { MetaLabel(label: "失败", value: "\(f.value)") }
                    if let d = item.duration_ms { MetaLabel(label: "耗时", value: "\(d.value)ms") }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private func statusIcon(_ status: String?) -> some View {
        let (icon, color): (UIImage, Color) = {
            switch status {
            case "success": return (AppIcon.check, .dsAccent)
            case "partial": return (AppIcon.warning, .dsAccentOrange)
            case "failed": return (AppIcon.close, .dsAccentPink)
            default: return (AppIcon.clock, .dsMuted)
            }
        }()
        return HIcon(icon)
            .font(.caption)
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: Circle())
    }

    // MARK: - Reload

    private func reload() async {
        async let h: () = vm.loadHistory(page: 1, type: filterType, status: filterStatus)
        async let s: () = vm.loadHistoryStats()
        _ = await (h, s)
    }
}
