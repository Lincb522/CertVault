import SwiftUI
import HiconIcons

struct GroupDetailSheet: View {
    let group: BetaGroup
    let accountId: String
    @Environment(\.dismiss) private var dismiss
    @State private var detail: BetaGroupDetail?
    @State private var isLoading = true
    @State private var showSettings = false
    @State private var showInviteTester = false
    @State private var showDeviceCriteria = false
    @State private var copiedLink = false
    @State private var toastMsg: String?

    private let service = AppStoreConnectService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    ScrollView {
                        VStack(spacing: 16) {
                            headerCard(detail)
                            actionBar(detail)
                            statsCard(detail)
                            publicLinkCard(detail)
                            settingsCard(detail)
                            if detail.is_internal != true {
                                deviceCriteriaCard(detail)
                            }
                            testersCard(detail)
                            buildsCard(detail)
                        }
                        .padding(16)
                    }
                } else {
                    VStack(spacing: 8) {
                        HIcon(AppIcon.warning)
                            .font(.title)
                            .foregroundStyle(Color.dsMuted)
                        Text("加载失败")
                            .foregroundStyle(Color.dsMuted)
                        Button("重试") { Task { await loadData() } }
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .pageBackground()
            .navigationTitle("测试组详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .sheet(isPresented: $showSettings) {
                if let detail {
                    GroupSettingsSheet(group: group, detail: detail, accountId: accountId, service: service) {
                        Task { await loadData() }
                    }
                }
            }
            .sheet(isPresented: $showInviteTester) {
                InviteTesterSheet(groupId: group.id, accountId: accountId, service: service) {
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showDeviceCriteria) {
                DeviceCriteriaSheet(
                    groupId: group.id, accountId: accountId,
                    existing: detail?.recruitment_criteria, service: service
                ) {
                    Task { await loadData() }
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMsg {
                    Text(msg)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.dsAccent, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = detail == nil
        do {
            detail = try await service.getGroupDetail(groupId: group.id, accountId: accountId)
        } catch {
            AppLogger.api.error("Group detail load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMsg = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { toastMsg = nil }
        }
    }

    // MARK: - Header

    private func headerCard(_ d: BetaGroupDetail) -> some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill((d.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange).opacity(0.12))
                    .frame(width: 56, height: 56)
                HIcon(d.is_internal == true ? AppIcon.personGroup : AppIcon.globe)
                    .font(.title2)
                    .foregroundStyle(d.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange)
            }
            Text(d.displayName)
                .font(.title3.bold())
                .foregroundStyle(Color.dsText)
            Text(d.typeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(d.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange, in: Capsule())
            if let date = d.created_date {
                Text("创建于 \(String(date.prefix(10)))")
                    .font(.caption2)
                    .foregroundStyle(Color.dsMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .cardStyle()
    }

    // MARK: - Action Bar

    private func actionBar(_ d: BetaGroupDetail) -> some View {
        HStack(spacing: 0) {
            actionButton("邀请测试员", icon: AppIcon.personAdd, color: .dsAccentBlue) {
                showInviteTester = true
            }

            if d.is_internal != true {
                actionDivider
                actionButton("设备条件", icon: AppIcon.iphone, color: .dsAccentOrange) {
                    showDeviceCriteria = true
                }
                actionDivider
                actionButton("分组设置", icon: AppIcon.gear, color: .dsAccentPurple) {
                    showSettings = true
                }
            }

            if let link = d.public_link, !link.isEmpty, d.public_link_enabled == true {
                actionDivider
                actionButton(copiedLink ? "已复制" : "复制链接", icon: copiedLink ? AppIcon.check : AppIcon.link, color: .dsAccent) {
                    UIPasteboard.general.string = link
                    withAnimation { copiedLink = true }
                    showToast("公开测试链接已复制")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedLink = false }
                    }
                }
            }
        }
        .cardStyle()
    }

    private var actionDivider: some View {
        Divider().frame(height: 40)
    }

    private func actionButton(_ title: String, icon: UIImage, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HIcon(icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12), in: Circle())
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private func statsCard(_ d: BetaGroupDetail) -> some View {
        HStack(spacing: 0) {
            statCell("测试员", value: d.tester_count ?? 0, icon: AppIcon.personGroup, color: .dsAccentBlue)
            Divider().frame(height: 44)
            statCell("构建", value: d.build_count ?? 0, icon: AppIcon.hammer, color: .dsAccentOrange)
        }
        .cardStyle()
    }

    private func statCell(_ label: String, value: Int, icon: UIImage, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                HIcon(icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Public Link

    @ViewBuilder
    private func publicLinkCard(_ d: BetaGroupDetail) -> some View {
        if let link = d.public_link, !link.isEmpty, d.public_link_enabled == true {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("公开测试链接")
                VStack(alignment: .leading, spacing: 10) {
                    Text(link)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.dsAccentBlue)
                        .textSelection(.enabled)

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = link
                            showToast("链接已复制")
                        } label: {
                            HStack(spacing: 4) {
                                HIcon(AppIcon.docCopy)
                                Text("复制")
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(.white)
                            .background(Color.dsAccentBlue, in: Capsule())
                        }

                        if let url = URL(string: link) {
                            ShareLink(item: url) {
                                HStack(spacing: 4) {
                                    HIcon(AppIcon.share)
                                    Text("分享")
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .foregroundStyle(Color.dsAccentBlue)
                                .background(Color.dsAccentBlue.opacity(0.12), in: Capsule())
                            }
                        }
                    }

                    if let limit = d.public_link_limit, d.public_link_limit_enabled == true {
                        Text("人数上限：\(limit)")
                            .font(.caption2)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Settings

    private func settingsCard(_ d: BetaGroupDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("分组设置")
                Spacer()
                if d.is_internal != true {
                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 3) {
                            HIcon(AppIcon.pencil)
                                .font(.caption2)
                            Text("编辑")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.dsAccentBlue)
                    }
                }
            }
            VStack(spacing: 8) {
                settingRow("反馈功能", enabled: d.feedback_enabled)
                settingRow("访问所有构建", enabled: d.has_access_to_all_builds)
                settingRow("公开链接", enabled: d.public_link_enabled)
                if d.public_link_limit_enabled == true, let limit = d.public_link_limit {
                    infoRow("公开链接人数上限", "\(limit)")
                }
            }
            .cardStyle()
        }
    }

    private func settingRow(_ label: String, enabled: Bool?) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
            Spacer()
            if let enabled {
                HIcon(enabled ? AppIcon.check : AppIcon.close)
                    .font(.subheadline)
                    .foregroundStyle(enabled ? Color.dsAccent : Color.dsMuted)
                Text(enabled ? "开启" : "关闭")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(enabled ? Color.dsAccent : Color.dsMuted)
            } else {
                Text("-").font(.subheadline).foregroundStyle(Color.dsMuted)
            }
        }
    }

    // MARK: - Device Criteria

    private func deviceCriteriaCard(_ d: BetaGroupDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("设备条件")
                Spacer()
                Button { showDeviceCriteria = true } label: {
                    HStack(spacing: 3) {
                        HIcon(AppIcon.pencil).font(.caption2)
                        Text("编辑").font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.dsAccentBlue)
                }
            }

            if let c = d.recruitment_criteria {
                VStack(spacing: 8) {
                    if let families = c.deviceFamilies, !families.isEmpty {
                        HStack {
                            Text("设备类型")
                                .font(.subheadline)
                                .foregroundStyle(Color.dsMuted)
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(families, id: \.self) { f in
                                    Text(deviceFamilyLabel(f))
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.dsAccentBlue.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.dsAccentBlue)
                                }
                            }
                        }
                    }
                    if let ver = c.minOsVersion, !ver.isEmpty {
                        infoRow("最低系统版本", "iOS \(ver)+")
                    }
                    if let check = c.requireDeviceCheck {
                        settingRow("设备验证", enabled: check)
                    }
                }
                .cardStyle()
            } else {
                VStack(spacing: 8) {
                    HIcon(AppIcon.iphoneSlash)
                        .font(.title3)
                        .foregroundStyle(Color.dsMuted.opacity(0.5))
                    Text("未设置设备条件")
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                    Text("设置后，通过公开链接加入的测试员需满足设备要求")
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                        .multilineTextAlignment(.center)
                    Button { showDeviceCriteria = true } label: {
                        Text("设置设备条件")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dsAccentBlue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .cardStyle()
            }
        }
    }

    private func deviceFamilyLabel(_ family: String) -> String {
        switch family.uppercased() {
        case "IPHONE": return "iPhone"
        case "IPAD": return "iPad"
        case "APPLE_TV", "APPLETV": return "Apple TV"
        case "MAC": return "Mac"
        case "APPLE_WATCH", "APPLEWATCH": return "Apple Watch"
        case "APPLE_VISION", "APPLEVISION": return "Vision Pro"
        default: return family
        }
    }

    // MARK: - Testers

    private func testersCard(_ d: BetaGroupDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("测试员 (\(d.testers?.count ?? 0))")
                Spacer()
                Button { showInviteTester = true } label: {
                    HStack(spacing: 3) {
                        HIcon(AppIcon.plus)
                            .font(.caption2)
                        Text("邀请")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.dsAccentBlue)
                }
            }

            if let testers = d.testers, !testers.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(testers.enumerated()), id: \.element.id) { idx, tester in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(testerStateColor(tester.state).opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Text(String(tester.displayName.prefix(1)).uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(testerStateColor(tester.state))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tester.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                if let email = tester.email {
                                    Text(email)
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsMuted)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(tester.stateLabel)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(testerStateColor(tester.state).opacity(0.12), in: Capsule())
                                    .foregroundStyle(testerStateColor(tester.state))
                                if let type = tester.invite_type {
                                    Text(inviteTypeLabel(type))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.dsMuted)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        if idx < testers.count - 1 {
                            Divider().foregroundStyle(Color.dsBorder)
                        }
                    }
                }
                .cardStyle()
            } else {
                VStack(spacing: 8) {
                    Text("暂无测试员")
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                    Button { showInviteTester = true } label: {
                        Text("邀请测试员")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dsAccentBlue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .cardStyle()
            }
        }
    }

    // MARK: - Builds

    private func buildsCard(_ d: BetaGroupDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("已分发构建 (\(d.builds?.count ?? 0))")

            if let builds = d.builds, !builds.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(builds.enumerated()), id: \.element.id) { idx, build in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.dsAccentOrange.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                HIcon(AppIcon.hammer)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsAccentOrange)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(build.displayVersion)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                if let date = build.uploaded_date {
                                    Text(String(date.prefix(10)))
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsMuted)
                                }
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                if build.expired == true {
                                    Text("已过期")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.dsAccentPink)
                                } else {
                                    Text(build.stateLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(build.processing_state == "VALID" ? Color.dsAccent : Color.dsMuted)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (build.expired == true ? Color.dsAccentPink : (build.processing_state == "VALID" ? Color.dsAccent : Color.dsMuted)).opacity(0.12),
                                in: Capsule()
                            )
                        }
                        .padding(.vertical, 8)
                        if idx < builds.count - 1 {
                            Divider().foregroundStyle(Color.dsBorder)
                        }
                    }
                }
                .cardStyle()
            } else {
                Text("暂无已分发构建")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .cardStyle()
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.dsText)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Color.dsMuted)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(Color.dsText)
        }
    }

    private func testerStateColor(_ state: String?) -> Color {
        switch state {
        case "ACCEPTED": return .dsAccent
        case "INVITED": return .dsAccentBlue
        case "NOT_INVITED": return .dsMuted
        case "REVOKED": return .dsAccentPink
        default: return .dsMuted
        }
    }

    private func inviteTypeLabel(_ type: String) -> String {
        switch type {
        case "EMAIL": return "邮件邀请"
        case "PUBLIC_LINK": return "公开链接"
        default: return type
        }
    }
}

// MARK: - Group Settings Sheet

private struct GroupSettingsSheet: View {
    let group: BetaGroup
    let detail: BetaGroupDetail
    let accountId: String
    let service: AppStoreConnectService
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var publicLinkEnabled = false
    @State private var publicLinkLimit = ""
    @State private var publicLinkLimitEnabled = false
    @State private var feedbackEnabled = false
    @State private var accessAllBuilds = false
    @State private var isSaving = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("分组名称", text: $name)
                }

                Section("公开链接") {
                    Toggle("启用公开链接", isOn: $publicLinkEnabled)
                    Toggle("限制人数", isOn: $publicLinkLimitEnabled)
                    if publicLinkLimitEnabled {
                        TextField("人数上限", text: $publicLinkLimit)
                            .keyboardType(.numberPad)
                    }
                }

                Section("测试设置") {
                    Toggle("反馈功能", isOn: $feedbackEnabled)
                    Toggle("访问所有构建", isOn: $accessAllBuilds)
                }

                if let err = errorMsg {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsAccentPink)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("编辑设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(isSaving || name.isEmpty)
                }
            }
            .onAppear {
                name = detail.name ?? ""
                publicLinkEnabled = detail.public_link_enabled ?? false
                publicLinkLimitEnabled = detail.public_link_limit_enabled ?? false
                publicLinkLimit = detail.public_link_limit.map { "\($0)" } ?? ""
                feedbackEnabled = detail.feedback_enabled ?? false
                accessAllBuilds = detail.has_access_to_all_builds ?? false
            }
        }
        .sheetStyle()
    }

    private func save() async {
        isSaving = true
        errorMsg = nil
        do {
            var settings = AppStoreConnectService.GroupSettingsUpdate(account_id: accountId)
            settings.name = name
            settings.public_link_enabled = publicLinkEnabled
            settings.public_link_limit_enabled = publicLinkLimitEnabled
            if publicLinkLimitEnabled, let limit = Int(publicLinkLimit) {
                settings.public_link_limit = limit
            }
            settings.feedback_enabled = feedbackEnabled
            settings.has_access_to_all_builds = accessAllBuilds
            try await service.updateGroup(groupId: group.id, accountId: accountId, settings: settings)
            onSaved()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Invite Tester Sheet

private struct InviteTesterSheet: View {
    let groupId: String
    let accountId: String
    let service: AppStoreConnectService
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var inviteMode = 0
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isInviting = false
    @State private var errorMsg: String?
    @State private var successMsg: String?
    @State private var existingTesters: [BetaTester] = []
    @State private var selectedTesterIds = Set<String>()
    @State private var isLoadingTesters = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("邀请方式", selection: $inviteMode) {
                        Text("新邀请").tag(0)
                        Text("从已有测试员选择").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if inviteMode == 0 {
                    Section("测试员信息") {
                        TextField("邮箱地址", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                        TextField("名（可选）", text: $firstName)
                        TextField("姓（可选）", text: $lastName)
                    }

                    Section {
                        Text("输入邮箱后，Apple 会向该邮箱发送 TestFlight 邀请")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                    }
                } else {
                    Section("选择已有测试员") {
                        if isLoadingTesters {
                            ProgressView("加载测试员...")
                                .frame(maxWidth: .infinity)
                        } else if existingTesters.isEmpty {
                            Text("暂无已有测试员")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(existingTesters) { tester in
                                Button {
                                    if selectedTesterIds.contains(tester.id) {
                                        selectedTesterIds.remove(tester.id)
                                    } else {
                                        selectedTesterIds.insert(tester.id)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        HIcon(selectedTesterIds.contains(tester.id) ? AppIcon.check : AppIcon.plusCircle)
                                            .foregroundStyle(selectedTesterIds.contains(tester.id) ? Color.dsAccentBlue : Color.dsMuted)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tester.displayName)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.dsText)
                                            if let email = tester.email {
                                                Text(email)
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.dsMuted)
                                            }
                                        }
                                        Spacer()
                                        Text(tester.stateLabel)
                                            .font(.caption2)
                                            .foregroundStyle(Color.dsMuted)
                                    }
                                }
                            }
                        }
                    }

                    if !selectedTesterIds.isEmpty {
                        Section {
                            Text("已选择 \(selectedTesterIds.count) 位测试员")
                                .font(.caption)
                                .foregroundStyle(Color.dsAccentBlue)
                        }
                    }
                }

                if let err = errorMsg {
                    Section {
                        Text(err).font(.caption).foregroundStyle(Color.dsAccentPink)
                    }
                }
                if let msg = successMsg {
                    Section {
                        Text(msg).font(.caption).foregroundStyle(Color.dsAccent)
                    }
                }

                Section {
                    Button {
                        Task { await invite() }
                    } label: {
                        HStack {
                            if isInviting { ProgressView().tint(.white) }
                            Text(inviteMode == 0 ? "发送邀请" : "添加到分组")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(canInvite ? .white : Color.dsMuted)
                        .background(canInvite ? Color.dsAccentBlue : Color.dsSurfaceLight, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .disabled(!canInvite || isInviting)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("邀请测试员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: inviteMode) { _ in
                if inviteMode == 1 && existingTesters.isEmpty {
                    Task { await loadExistingTesters() }
                }
            }
        }
        .sheetStyle()
    }

    private var canInvite: Bool {
        if inviteMode == 0 {
            return !email.isEmpty && email.contains("@")
        } else {
            return !selectedTesterIds.isEmpty
        }
    }

    private func loadExistingTesters() async {
        isLoadingTesters = true
        do {
            existingTesters = try await service.listTesters(accountId: accountId)
        } catch {}
        isLoadingTesters = false
    }

    private func invite() async {
        isInviting = true
        errorMsg = nil
        successMsg = nil
        do {
            if inviteMode == 0 {
                try await service.createTester(
                    accountId: accountId,
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    groupIds: [groupId]
                )
                successMsg = "邀请已发送到 \(email)"
                email = ""
                firstName = ""
                lastName = ""
            } else {
                try await service.addTestersToGroup(
                    groupId: groupId,
                    accountId: accountId,
                    testerIds: Array(selectedTesterIds)
                )
                successMsg = "已添加 \(selectedTesterIds.count) 位测试员到分组"
                selectedTesterIds.removeAll()
            }
            onDone()
        } catch {
            errorMsg = error.localizedDescription
        }
        isInviting = false
    }
}

// MARK: - Device Criteria Sheet

private struct DeviceCriteriaSheet: View {
    let groupId: String
    let accountId: String
    let existing: RecruitmentCriteria?
    let service: AppStoreConnectService
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var enableIPhone = true
    @State private var enableIPad = true
    @State private var enableMac = false
    @State private var enableAppleTV = false
    @State private var enableVisionPro = false
    @State private var minOsVersion = ""
    @State private var requireDeviceCheck = false
    @State private var isSaving = false
    @State private var errorMsg: String?
    @State private var showDeleteConfirm = false

    private var hasExisting: Bool { existing?.id != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("设备条件限制", systemImage: "iphone.gen3")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                        Text("设置通过公开链接加入的测试员的设备和系统版本要求")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                    }
                }

                Section("允许的设备类型") {
                    Toggle("iPhone", isOn: $enableIPhone)
                    Toggle("iPad", isOn: $enableIPad)
                    Toggle("Mac", isOn: $enableMac)
                    Toggle("Apple TV", isOn: $enableAppleTV)
                    Toggle("Vision Pro", isOn: $enableVisionPro)
                }

                Section("最低系统版本") {
                    TextField("例如：16.0", text: $minOsVersion)
                        .keyboardType(.decimalPad)
                    Text("留空表示不限制最低版本")
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }

                Section("其他") {
                    Toggle("需要设备验证", isOn: $requireDeviceCheck)
                    Text("开启后会验证测试员设备的完整性")
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }

                if let err = errorMsg {
                    Section {
                        Text(err).font(.caption).foregroundStyle(Color.dsAccentPink)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(hasExisting ? "更新设备条件" : "设置设备条件")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .disabled(isSaving)
                }

                if hasExisting {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                HIcon(AppIcon.trash)
                                Text("移除设备条件")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("设备条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("确认移除", isPresented: $showDeleteConfirm) {
                Button("移除", role: .destructive) {
                    Task { await deleteCriteria() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("移除后，通过公开链接加入的测试员将不再受设备限制")
            }
            .onAppear { loadExisting() }
        }
        .sheetStyle()
    }

    private func loadExisting() {
        guard let c = existing else { return }
        let families = Set(c.deviceFamilies?.map { $0.uppercased() } ?? [])
        if !families.isEmpty {
            enableIPhone = families.contains("IPHONE")
            enableIPad = families.contains("IPAD")
            enableMac = families.contains("MAC")
            enableAppleTV = families.contains("APPLE_TV") || families.contains("APPLETV")
            enableVisionPro = families.contains("APPLE_VISION") || families.contains("APPLEVISION")
        }
        minOsVersion = c.minOsVersion ?? ""
        requireDeviceCheck = c.requireDeviceCheck ?? false
    }

    private var selectedFamilies: [String] {
        var families: [String] = []
        if enableIPhone { families.append("IPHONE") }
        if enableIPad { families.append("IPAD") }
        if enableMac { families.append("MAC") }
        if enableAppleTV { families.append("APPLE_TV") }
        if enableVisionPro { families.append("APPLE_VISION") }
        return families
    }

    private func save() async {
        isSaving = true
        errorMsg = nil
        do {
            var body = AppStoreConnectService.DeviceCriteriaBody(account_id: accountId)
            body.device_families = selectedFamilies
            body.min_os_version = minOsVersion.isEmpty ? nil : minOsVersion
            body.require_device_check = requireDeviceCheck

            if hasExisting {
                try await service.updateDeviceCriteria(groupId: groupId, accountId: accountId, body: body)
            } else {
                try await service.createDeviceCriteria(groupId: groupId, accountId: accountId, body: body)
            }
            onSaved()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }

    private func deleteCriteria() async {
        isSaving = true
        do {
            try await service.deleteDeviceCriteria(groupId: groupId, accountId: accountId)
            onSaved()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }
}
