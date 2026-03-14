import SwiftUI
import HiconIcons

struct ScheduledPushView: View {
    @StateObject private var vm = PushViewModel()
    @State private var showCreateSheet = false
    @State private var filterStatus: String?
    @State private var animateContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                statsSection
                    .staggeredAnimation(index: 0, trigger: animateContent)

                filterSection
                    .staggeredAnimation(index: 1, trigger: animateContent)

                listSection
                    .staggeredAnimation(index: 2, trigger: animateContent)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
        .pageBackground()
        .navigationTitle("定时推送")
        .refreshable { await vm.loadScheduled(status: filterStatus) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateSheet = true } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .glassSheet(isPresented: $showCreateSheet) {
            CreateScheduledPushSheet(vm: vm) { showCreateSheet = false }
        }
        .task {
            await vm.loadScheduled()
            withAnimation(DS.Animation.normal) { animateContent = true }
        }
        .onChange(of: filterStatus) { Task { await vm.loadScheduled(status: filterStatus) } }
    }

    // MARK: - Stats

    private var statsSection: some View {
        InlineStatGrid(items: {
            let pending = vm.scheduledItems.filter { $0.status == "pending" }.count
            let done = vm.scheduledItems.filter { $0.status == "success" || $0.status == "partial" }.count
            let failed = vm.scheduledItems.filter { $0.status == "failed" }.count
            return [
                ("总计", vm.scheduledTotal, .dsAccentBlue),
                ("待执行", pending, .dsAccentOrange),
                ("已完成", done, .dsAccent),
                ("失败", failed, .dsAccentPink),
            ]
        }())
    }

    // MARK: - Filter

    private var filterSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Menu {
                Button("全部") { filterStatus = nil }
                Button("待执行") { filterStatus = "pending" }
                Button("已完成") { filterStatus = "success" }
                Button("失败") { filterStatus = "failed" }
                Button("已取消") { filterStatus = "cancelled" }
            } label: {
                HStack(spacing: 4) {
                    Text("状态: \(filterStatus ?? "全部")")
                        .font(.caption.weight(.medium))
                    HIcon(AppIcon.down).font(.caption2)
                }
                .foregroundStyle(Color.dsAccentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.dsAccentBlue.opacity(0.08), in: Capsule())
            }

            Spacer()

            Text("共 \(vm.scheduledTotal) 条")
                .font(.caption)
                .foregroundStyle(Color.dsMuted)
        }
    }

    // MARK: - List

    private var listSection: some View {
        VStack(spacing: 0) {
            if vm.isLoading && vm.scheduledItems.isEmpty {
                LoadingView()
                    .frame(minHeight: 200)
            } else if vm.scheduledItems.isEmpty {
                EmptyStateView(
                    icon: AppIcon.clock,
                    title: "暂无定时推送",
                    message: "创建定时推送任务，在指定时间自动发送",
                    actionTitle: "创建"
                ) { showCreateSheet = true }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.scheduledItems.enumerated()), id: \.element.stableId) { index, item in
                        scheduledRow(item)

                        if index < vm.scheduledItems.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
                .glassCard(cornerRadius: DS.Radius.lg)

                if vm.scheduledItems.count < vm.scheduledTotal {
                    Button {
                        Task { await vm.loadScheduled(page: vm.scheduledPage + 1, status: filterStatus) }
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

    private func scheduledRow(_ item: ScheduledPush) -> some View {
        HStack(spacing: 12) {
            statusCircle(item.status)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    TypeBadge(
                        text: item.typeLabel,
                        color: item.type == "broadcast" ? .dsAccentOrange : .dsAccentBlue
                    )
                    StatusBadge(item.statusLabel, color: Color.forStatus(item.status))
                    Spacer()
                    if let t = item.scheduled_at {
                        Text(formatDate(t))
                            .font(.caption2)
                            .foregroundStyle(Color.dsMuted)
                            .lineLimit(1)
                    }
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

                if let result = item.result {
                    HStack(spacing: 10) {
                        if let total = result.total { MetaLabel(label: "目标", value: "\(total)") }
                        if let s = result.success { MetaLabel(label: "成功", value: "\(s)") }
                        if let f = result.failed, f > 0 { MetaLabel(label: "失败", value: "\(f)") }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .contextMenu {
            if item.status == "pending" {
                Button(role: .destructive) {
                    if let id = item.id { Task { try? await vm.cancelScheduled(id: id) } }
                } label: {
                    Label("取消任务", systemImage: "xmark.circle")
                }
            }
            Button(role: .destructive) {
                if let id = item.id { Task { try? await vm.deleteScheduled(id: id) } }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func statusCircle(_ status: String?) -> some View {
        let (icon, color): (UIImage, Color) = {
            switch status {
            case "pending": return (AppIcon.clock, .dsAccentOrange)
            case "executing": return (AppIcon.play, .dsAccentBlue)
            case "success": return (AppIcon.check, .dsAccent)
            case "partial": return (AppIcon.warning, .dsAccentOrange)
            case "failed": return (AppIcon.close, .dsAccentPink)
            case "cancelled": return (AppIcon.stop, .dsMuted)
            default: return (AppIcon.clock, .dsMuted)
            }
        }()
        return HIcon(icon)
            .font(.caption)
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: Circle())
    }

    private func formatDate(_ str: String) -> String {
        str.toLocalDate()
    }
}

// MARK: - Create Scheduled Push Sheet

private struct CreateScheduledPushSheet: View {
    @ObservedObject var vm: PushViewModel
    let onDismiss: () -> Void

    @State private var type = "broadcast"
    @State private var title = ""
    @State private var bodyText = ""
    @State private var bundleId = ""
    @State private var sandbox = false
    @State private var deviceToken = ""
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var isCreating = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("推送类型") {
                    Picker("类型", selection: $type) {
                        Text("广播").tag("broadcast")
                        Text("单推").tag("single")
                    }
                    .pickerStyle(.segmented)
                }

                Section("推送内容") {
                    TextField("标题", text: $title)
                    TextField("正文（可选）", text: $bodyText, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("目标设置") {
                    TextField("Bundle ID（可选，使用默认）", text: $bundleId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("沙盒环境", isOn: $sandbox)

                    if type == "single" {
                        TextField("Device Token", text: $deviceToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section("定时") {
                    DatePicker("执行时间", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsAccentPink)
                    }
                }

                Section {
                    GradientButton("创建定时推送", icon: AppIcon.clock) {
                        Task { await create() }
                    }
                    .disabled(title.isEmpty || isCreating)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("创建定时推送")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onDismiss() }
                }
            }
        }
        .sheetStyle()
    }

    private func create() async {
        isCreating = true
        errorMsg = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateStr = formatter.string(from: scheduledDate)

        let item = ScheduledPushCreate(
            type: type,
            title: title,
            body: bodyText.isEmpty ? nil : bodyText,
            bundle_id: bundleId.isEmpty ? nil : bundleId,
            sandbox: sandbox,
            device_token: type == "single" ? (deviceToken.isEmpty ? nil : deviceToken) : nil,
            scheduled_at: dateStr
        )

        do {
            try await vm.createScheduled(item)
            onDismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isCreating = false
    }
}
