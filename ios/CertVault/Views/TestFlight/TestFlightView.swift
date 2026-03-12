import SwiftUI
import HiconIcons

struct TestFlightView: View {
    @StateObject private var vm = TestFlightViewModel()
    @State private var selectedTab = 0
    @State private var showCreateGroup = false
    @State private var showAddTester = false
    @State private var showGroupTesters: BetaGroup?
    @State private var showDistributeBuild: BetaGroup?
    @State private var showBuildDetail: AppBuild?
    @State private var groupToDelete: BetaGroup?
    @State private var showGroupDetail: BetaGroup?
    @State private var showTestSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                accountAppPicker

                segmentedControl

                if vm.isLoading {
                    LoadingView().frame(height: 200)
                } else {
                    switch selectedTab {
                    case 0: groupsSection
                    case 1: testersSection
                    default: buildsSection
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle("TestFlight")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showCreateGroup = true } label: {
                        Label("新建分组", systemImage: "folder.badge.plus")
                    }
                    Button { showAddTester = true } label: {
                        Label("添加测试员", systemImage: "person.badge.plus")
                    }
                    Divider()
                    Button { showTestSettings = true } label: {
                        Label("测试条件设置", systemImage: "checklist")
                    }
                } label: {
                    HIcon(AppIcon.add).font(.body)
                }
            }
        }
        .glassSheet(isPresented: $showCreateGroup) {
            CreateGroupSheet(vm: vm)
        }
        .glassSheet(isPresented: $showAddTester) {
            AddTesterSheet(vm: vm)
        }
        .glassSheet(item: $showGroupTesters) { group in
            GroupTestersSheet(vm: vm, group: group)
        }
        .glassSheet(item: $showDistributeBuild) { group in
            DistributeBuildSheet(vm: vm, group: group)
        }
        .glassSheet(item: $showBuildDetail) { build in
            BuildDetailSheet(build: build, accountId: vm.selectedAccountId)
        }
        .glassSheet(item: $showGroupDetail) { group in
            GroupDetailSheet(group: group, accountId: vm.selectedAccountId)
        }
        .glassSheet(isPresented: $showTestSettings) {
            if !vm.selectedAppId.isEmpty {
                BetaTestSettingsSheet(appId: vm.selectedAppId, accountId: vm.selectedAccountId)
            }
        }
        .alert("确认删除测试组", isPresented: .init(
            get: { groupToDelete != nil },
            set: { if !$0 { groupToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let group = groupToDelete {
                    Task { try? await vm.deleteGroup(id: group.id) }
                }
                groupToDelete = nil
            }
            Button("取消", role: .cancel) { groupToDelete = nil }
        } message: {
            Text("确定要删除测试组「\(groupToDelete?.name ?? "")」吗？此操作不可撤销。")
        }
        .onChange(of: selectedTab) { _ in
            Task { await loadTabData() }
        }
        .task { await vm.loadAccounts() }
    }

    private func loadTabData() async {
        switch selectedTab {
        case 0: await vm.loadGroups()
        case 1: await vm.loadTesters()
        default: await vm.loadBuilds()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.dsAccentPurple, .dsAccentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                HIcon(AppIcon.pushTest)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("TestFlight")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text("管理测试分组、测试员和构建版本")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Pickers

    private var accountAppPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.dsAccentBlue.opacity(0.12))
                        .frame(width: 32, height: 32)
                    HIcon(AppIcon.account)
                        .font(.caption)
                        .foregroundStyle(Color.dsAccentBlue)
                }
                Picker("账号", selection: $vm.selectedAccountId) {
                    Text("请选择账号").tag("")
                    ForEach(vm.accounts) { acc in Text(acc.displayName).tag(acc.id) }
                }
                .tint(Color.dsAccentBlue)
                .onChange(of: vm.selectedAccountId) { _ in
                    Task {
                        await vm.loadApps()
                        await loadTabData()
                    }
                }
            }
            .padding(.bottom, 10)

            Divider().foregroundStyle(Color.dsBorder)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.dsAccentPurple.opacity(0.12))
                        .frame(width: 32, height: 32)
                    HIcon(AppIcon.category)
                        .font(.caption)
                        .foregroundStyle(Color.dsAccentPurple)
                }
                Picker("应用", selection: $vm.selectedAppId) {
                    Text("全部应用").tag("")
                    ForEach(vm.apps) { app in Text(app.displayName).tag(app.id) }
                }
                .tint(Color.dsAccentBlue)
                .onChange(of: vm.selectedAppId) { _ in
                    Task { await loadTabData() }
                }
            }
            .padding(.top, 10)
        }
        .cardStyle()
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            tabButton("测试分组", icon: AppIcon.folder, tag: 0)
            tabButton("测试员", icon: AppIcon.personGroup, tag: 1)
            tabButton("构建版本", icon: AppIcon.hammer, tag: 2)
        }
        .padding(4)
        .glassCard(cornerRadius: 12)
    }

    private func tabButton(_ title: String, icon: UIImage, tag: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tag } } label: {
            HStack(spacing: 5) {
                HIcon(icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(selectedTab == tag ? .white : Color.dsMuted)
            .background(
                selectedTab == tag ? Color.dsAccentBlue : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Groups

    private var groupsSection: some View {
        LazyVStack(spacing: 10) {
            if vm.groups.isEmpty {
                EmptyStateView(icon: AppIcon.group, title: "暂无分组", message: "创建测试分组来分发构建版本")
            } else {
                ForEach(vm.groups) { group in
                    Button { showGroupDetail = group } label: {
                        groupCard(group)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func groupCard(_ group: BetaGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill((group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange).opacity(0.12))
                        .frame(width: 40, height: 40)
                    HIcon(group.is_internal == true ? AppIcon.personGroup : AppIcon.globe)
                        .font(.callout)
                        .foregroundStyle(group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsText)
                    HStack(spacing: 6) {
                        Text(group.typeLabel)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange).opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange)
                        if group.public_link_enabled == true {
                            HIcon(AppIcon.link)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.dsAccentCyan)
                        }
                        if let date = group.created_date {
                            Text(date)
                                .font(.caption2)
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                }
                Spacer()

                Menu {
                    Button { showGroupDetail = group } label: {
                        Label("查看详情", systemImage: "info.circle")
                    }
                    Button { showGroupTesters = group } label: {
                        Label("查看测试员", systemImage: "person.2")
                    }
                    Button { showDistributeBuild = group } label: {
                        Label("分发构建", systemImage: "paperplane")
                    }
                    Divider()
                    Button(role: .destructive) {
                        groupToDelete = group
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    HIcon(AppIcon.moreCircle)
                        .font(.body)
                        .foregroundStyle(Color.dsMuted)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Testers

    private var testersSection: some View {
        LazyVStack(spacing: 10) {
            if vm.testers.isEmpty {
                EmptyStateView(icon: AppIcon.user, title: "暂无测试员", message: "添加测试员以邀请外部用户参与测试")
            } else {
                ForEach(vm.testers) { tester in
                    testerCard(tester)
                }
            }
        }
    }

    private func testerCard(_ tester: BetaTester) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: avatarGradient(for: tester.displayName),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Text(String(tester.displayName.prefix(1)).uppercased())
                    .font(.callout.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tester.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                Text(tester.email ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
                    .lineLimit(1)
            }

            Spacer()

            Text(tester.stateLabel)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(testerStateColor(tester.state).opacity(0.12), in: Capsule())
                .foregroundStyle(testerStateColor(tester.state))
        }
        .cardStyle()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { try? await vm.deleteTester(id: tester.id) }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func testerStateColor(_ state: String?) -> Color {
        switch state {
        case "ACCEPTED": return .dsAccent
        case "INVITED": return .dsAccentBlue
        case "NOT_INVITED": return .dsMuted
        default: return .dsAccentOrange
        }
    }

    private func avatarGradient(for name: String) -> [Color] {
        let hash = abs(name.hashValue)
        let pairs: [[Color]] = [
            [.dsAccentPurple, .dsAccentPink],
            [.dsAccentBlue, .dsAccentCyan],
            [.dsAccentOrange, .dsAccentPink],
            [.dsAccent, .dsAccentCyan],
            [.dsAccentBlue, .dsAccentPurple],
        ]
        return pairs[hash % pairs.count]
    }

    // MARK: - Builds

    private var buildsSection: some View {
        LazyVStack(spacing: 10) {
            if vm.builds.isEmpty {
                EmptyStateView(icon: AppIcon.category, title: "暂无构建", message: "请先选择应用以查看构建版本")
            } else {
                ForEach(vm.builds) { build in
                    Button { showBuildDetail = build } label: {
                        buildCard(build)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func buildCard(_ build: AppBuild) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(buildIconColor(build).opacity(0.1))
                        .frame(width: 40, height: 40)
                    HIcon(AppIcon.hammer)
                        .font(.callout)
                        .foregroundStyle(buildIconColor(build))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(build.displayVersion)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dsText)
                        if build.expired == true {
                            Text("已过期")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.dsAccentPink.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.dsAccentPink)
                        }
                    }
                    if let date = build.uploaded_date {
                        Text(String(date.prefix(16)))
                            .font(.caption2)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
                Spacer()
                StatusBadge(build.stateLabel, color: build.processing_state == "VALID" ? .dsAccent : .dsMuted)
                HIcon(AppIcon.chevronRight)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.dsMuted.opacity(0.4))
            }

            if build.processing_state == "VALID" {
                HStack(spacing: 12) {
                    if let ext = build.external_build_state {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(betaColor(build.betaStateColor.external))
                                .frame(width: 6, height: 6)
                            Text("外部")
                                .font(.caption2)
                                .foregroundStyle(Color.dsMuted)
                            Text(build.externalStateLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(betaColor(build.betaStateColor.external))
                        }
                    }
                    if let int = build.internal_build_state {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(betaColor(build.betaStateColor.internal))
                                .frame(width: 6, height: 6)
                            Text("内部")
                                .font(.caption2)
                                .foregroundStyle(Color.dsMuted)
                            Text(build.internalStateLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(betaColor(build.betaStateColor.internal))
                        }
                    }
                    Spacer()
                    if let os = build.min_os_version {
                        Text("iOS \(os)+")
                            .font(.caption2)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func buildIconColor(_ build: AppBuild) -> Color {
        if build.expired == true { return .dsAccentPink }
        switch build.processing_state {
        case "VALID": return .dsAccentBlue
        case "PROCESSING": return .dsAccentOrange
        case "FAILED", "INVALID": return .dsAccentPink
        default: return .dsMuted
        }
    }

    private func betaColor(_ name: String) -> Color {
        switch name {
        case "green": return .dsAccent
        case "orange": return .dsAccentOrange
        case "red": return .dsAccentPink
        case "blue": return .dsAccentBlue
        default: return .dsMuted
        }
    }
}

// MARK: - Create Group Sheet

private struct CreateGroupSheet: View {
    @ObservedObject var vm: TestFlightViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isInternal = false
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("分组名称", text: $name)
                Toggle("内部分组", isOn: $isInternal)
            }
            .navigationTitle("新建分组")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        isCreating = true
                        Task {
                            try? await vm.createGroup(name: name, isInternal: isInternal)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.medium])
    }
}

// MARK: - Add Tester Sheet

private struct AddTesterSheet: View {
    @ObservedObject var vm: TestFlightViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedGroupId = ""
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Form {
                Section("测试员信息") {
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("名", text: $firstName)
                    TextField("姓", text: $lastName)
                }
                Section("加入分组（可选）") {
                    Picker("分组", selection: $selectedGroupId) {
                        Text("不加入").tag("")
                        ForEach(vm.groups) { g in Text(g.displayName).tag(g.id) }
                    }
                }
            }
            .navigationTitle("添加测试员")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        isAdding = true
                        Task {
                            try? await vm.createTester(
                                email: email,
                                firstName: firstName,
                                lastName: lastName,
                                groupIds: selectedGroupId.isEmpty ? [] : [selectedGroupId]
                            )
                            dismiss()
                        }
                    }
                    .disabled(email.isEmpty || isAdding)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.medium])
    }
}

// MARK: - Group Testers Sheet

private struct GroupTestersSheet: View {
    @ObservedObject var vm: TestFlightViewModel
    let group: BetaGroup
    @Environment(\.dismiss) private var dismiss
    @State private var showAddTesterPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.groupTesters.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.user,
                        title: "暂无测试员",
                        message: "该分组暂无测试员，点击右上角添加"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.groupTesters) { t in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.dsAccentPurple.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Text(String(t.displayName.prefix(1)).uppercased())
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.dsAccentPurple)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.dsText)
                                        Text(t.email ?? "")
                                            .font(.caption)
                                            .foregroundStyle(Color.dsMuted)
                                    }
                                    Spacer()
                                    Text(t.stateLabel)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.dsMuted.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.dsMuted)

                                    Button(role: .destructive) {
                                        Task { try? await vm.removeTestersFromGroup(groupId: group.id, testerIds: [t.id]) }
                                    } label: {
                                        HIcon(AppIcon.minusCircle)
                                            .font(.body)
                                            .foregroundStyle(Color.dsAccentPink)
                                    }
                                }
                                .cardStyle()
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("\(group.displayName) 测试员")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddTesterPicker = true } label: {
                        HIcon(AppIcon.personAdd)
                    }
                }
            }
            .glassSheet(isPresented: $showAddTesterPicker) {
                AddTesterToGroupSheet(vm: vm, group: group)
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await vm.loadGroupTesters(groupId: group.id) }
    }
}

// MARK: - Add Tester To Group Sheet

private struct AddTesterToGroupSheet: View {
    @ObservedObject var vm: TestFlightViewModel
    let group: BetaGroup
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTesterIds = Set<String>()
    @State private var isAdding = false

    private var availableTesters: [BetaTester] {
        let existingIds = Set(vm.groupTesters.map(\.id))
        return vm.testers.filter { !existingIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.testers.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.user,
                        title: "暂无可用测试员",
                        message: "请先在测试员列表中添加测试员"
                    )
                } else if availableTesters.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.user,
                        title: "所有测试员已在分组中",
                        message: "没有可以添加的测试员"
                    )
                } else {
                    List(availableTesters, selection: $selectedTesterIds) { tester in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tester.displayName)
                                    .font(.subheadline.weight(.medium))
                                Text(tester.email ?? "")
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
                            }
                            Spacer()
                            Text(tester.stateLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.dsMuted)
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("添加到 \(group.displayName)")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加 (\(selectedTesterIds.count))") {
                        isAdding = true
                        Task {
                            try? await vm.addTestersToGroup(groupId: group.id, testerIds: Array(selectedTesterIds))
                            dismiss()
                        }
                    }
                    .disabled(selectedTesterIds.isEmpty || isAdding)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await vm.loadTesters() }
    }
}

// MARK: - Distribute Build Sheet

private struct DistributeBuildSheet: View {
    @ObservedObject var vm: TestFlightViewModel
    let group: BetaGroup
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBuildIds = Set<String>()
    @State private var whatsNew = ""
    @State private var locale = "zh-Hans"
    @State private var isDistributing = false
    @State private var showTemplateList = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var distributeError: String?
    @State private var distributeSuccess = false

    private let localeOptions = [
        ("zh-Hans", "简体中文"),
        ("en-US", "English (US)"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語"),
        ("ko", "한국어"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if vm.builds.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.info,
                        title: "暂无可用构建版本",
                        message: "请先选择应用并确保有上传的构建版本"
                    )
                } else {
                    VStack(spacing: 0) {
                        List(vm.builds, selection: $selectedBuildIds) { build in
                            HStack {
                                Text("v\(build.version ?? "-")")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                StatusBadge(build.stateLabel, color: build.processing_state == "VALID" ? .dsAccent : .dsMuted)
                            }
                        }
                        .environment(\.editMode, .constant(.active))
                        .frame(maxHeight: 200)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Button {
                                    showTemplateList = true
                                } label: {
                                    HStack(spacing: 6) {
                                        HIcon(AppIcon.docCopy)
                                            .font(.caption)
                                        Text("使用模版")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(Color.dsAccentBlue)
                                    .background(Color.dsAccentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showSaveTemplate = true
                                } label: {
                                    HStack(spacing: 6) {
                                        HIcon(AppIcon.download)
                                            .font(.caption)
                                        Text("存为模版")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(Color.dsAccentPurple)
                                    .background(Color.dsAccentPurple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }

                            Text("测试内容 (What to Test)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dsText)

                            TextEditor(text: $whatsNew)
                                .frame(minHeight: 80)
                                .padding(8)
                                .glassCard(cornerRadius: 10)

                            HStack {
                                Text("语言")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsMuted)
                                Picker("", selection: $locale) {
                                    ForEach(localeOptions, id: \.0) { opt in
                                        Text(opt.1).tag(opt.0)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("分发到 \(group.displayName)")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("分发") {
                        isDistributing = true
                        Task {
                            do {
                                try await vm.addBuildsToGroup(
                                    groupId: group.id,
                                    buildIds: Array(selectedBuildIds),
                                    whatsNew: whatsNew.isEmpty ? nil : whatsNew,
                                    locale: locale
                                )
                                distributeSuccess = true
                            } catch {
                                isDistributing = false
                                distributeError = error.localizedDescription
                            }
                        }
                    }
                    .disabled(selectedBuildIds.isEmpty || isDistributing)
                }
            }
            .glassSheet(isPresented: $showTemplateList) {
                TemplatePickerSheet(type: .testFlight) { template in
                    whatsNew = template.whatsNew ?? ""
                    if let loc = template.locale { locale = loc }
                }
            }
            .alert("保存为模版", isPresented: $showSaveTemplate) {
                TextField("模版名称", text: $templateName)
                Button("保存") { saveAsTemplate() }
                Button("取消", role: .cancel) { templateName = "" }
            } message: {
                Text("为当前填写内容命名，方便下次快速使用")
            }
            .alert("分发成功", isPresented: $distributeSuccess) {
                Button("好的") { dismiss() }
            } message: {
                Text("已成功将 \(selectedBuildIds.count) 个构建版本分发到「\(group.displayName)」")
            }
            .alert("分发失败", isPresented: .init(
                get: { distributeError != nil },
                set: { if !$0 { distributeError = nil } }
            )) {
                Button("好的") { distributeError = nil }
            } message: {
                Text(distributeError ?? "未知错误")
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await vm.loadBuilds() }
    }

    private func saveAsTemplate() {
        guard !templateName.isEmpty else { return }
        let template = SubmitTemplate(
            name: templateName,
            type: .testFlight,
            locale: locale,
            whatsNew: whatsNew.isEmpty ? nil : whatsNew
        )
        try? DatabaseManager.shared.saveTemplate(template)
        templateName = ""
    }
}
