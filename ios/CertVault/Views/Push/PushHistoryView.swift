import SwiftUI
import HiconIcons

struct PushHistoryView: View {
    @StateObject private var vm = PushViewModel()
    @State private var filterType: String?
    @State private var filterStatus: String?
    @State private var showClearAlert = false

    var body: some View {
        List {
            statsSection
            filterSection
            historyListSection
        }
        .scrollContentBackground(.hidden)
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
        .task { await reload() }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats = vm.historyStats {
            Section("统计概览") {
                HStack(spacing: 0) {
                    statCell("总推送", value: stats.total_pushes?.value ?? 0, color: .dsAccentBlue)
                    Divider().frame(height: 40)
                    statCell("今日", value: stats.today_pushes?.value ?? 0, color: .dsAccentPurple)
                    Divider().frame(height: 40)
                    statCell("已送达", value: stats.total_delivered?.value ?? 0, color: .dsAccent)
                    Divider().frame(height: 40)
                    statCell("失败", value: stats.total_failed?.value ?? 0, color: .dsAccentPink)
                }
                    .listRowBackground(Color.clear)

                HStack(spacing: 0) {
                    statCell("单推", value: stats.singles?.value ?? 0, color: .dsAccentCyan)
                    Divider().frame(height: 40)
                    statCell("广播", value: stats.broadcasts?.value ?? 0, color: .dsAccentOrange)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var filterSection: some View {
        Section {
            HStack(spacing: 12) {
                Menu {
                    Button("全部") { filterType = nil }
                    Button("单推") { filterType = "single" }
                    Button("广播") { filterType = "broadcast" }
                } label: {
                    HStack(spacing: 4) {
                        Text("类型: \(filterType == nil ? "全部" : (filterType == "broadcast" ? "广播" : "单推"))")
                            .font(.caption)
                        HIcon(AppIcon.down)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.dsAccentBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dsAccentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                Menu {
                    Button("全部") { filterStatus = nil }
                    Button("成功") { filterStatus = "success" }
                    Button("部分成功") { filterStatus = "partial" }
                    Button("失败") { filterStatus = "failed" }
                } label: {
                    HStack(spacing: 4) {
                        Text("状态: \(filterStatus ?? "全部")")
                            .font(.caption)
                        HIcon(AppIcon.down)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.dsAccentPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dsAccentPurple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Text("共 \(vm.historyTotal) 条")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            .listRowBackground(Color.clear)
        }
        .onChange(of: filterType) { Task { await reload() } }
        .onChange(of: filterStatus) { Task { await reload() } }
    }

    private var historyListSection: some View {
        Section {
            if vm.isLoading && vm.historyItems.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if vm.historyItems.isEmpty {
                VStack(spacing: 12) {
                    HIcon(AppIcon.bellSlash)
                        .font(.system(size: 36))
                        .foregroundStyle(Color.dsMuted)
                    Text("暂无推送记录")
                        .font(.headline)
                        .foregroundStyle(Color.dsText)
                    Text("发送推送后将在此显示历史记录")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .listRowBackground(Color.clear)
            } else {
                ForEach(vm.historyItems, id: \.stableId) { item in
                    historyRow(item)
                        .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    Task {
                        for idx in offsets {
                            if let id = vm.historyItems[idx].id {
                                try? await vm.deleteHistoryItem(id: id)
                            }
                        }
                    }
                }

                if vm.historyItems.count < vm.historyTotal {
                    Button("加载更多") {
                        Task { await vm.loadHistory(page: vm.historyPage + 1, type: filterType, status: filterStatus) }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.dsAccentBlue)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private func historyRow(_ item: PushHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.typeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.type == "broadcast" ? Color.dsAccentOrange : Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 4))

                statusBadge(item.statusLabel, status: item.status)

                Spacer()

                Text(item.created_at ?? "")
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

            HStack(spacing: 12) {
                if let t = item.target_count { metaLabel("目标", "\(t.value)") }
                if let s = item.success_count { metaLabel("成功", "\(s.value)") }
                if let f = item.failed_count, f.value > 0 { metaLabel("失败", "\(f.value)") }
                if let d = item.duration_ms { metaLabel("耗时", "\(d.value)ms") }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ text: String, status: String?) -> some View {
        let color: Color = {
            switch status {
            case "success": return .dsAccent
            case "partial": return .dsAccentOrange
            case "failed": return .dsAccentPink
            default: return .dsMuted
            }
        }()

        return Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
    }

    private func metaLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label).foregroundStyle(Color.dsMuted)
            Text(value).foregroundStyle(Color.dsText)
        }
        .font(.caption2)
    }

    private func statCell(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func reload() async {
        async let h: () = vm.loadHistory(page: 1, type: filterType, status: filterStatus)
        async let s: () = vm.loadHistoryStats()
        _ = await (h, s)
    }
}
