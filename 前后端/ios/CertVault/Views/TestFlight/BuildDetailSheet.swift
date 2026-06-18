import SwiftUI

struct BuildDetailSheet: View {
    let build: AppBuild
    let accountId: String
    @Environment(\.dismiss) private var dismiss
    @State private var detail: BuildDetail?
    @State private var isLoading = true
    @State private var editingWhatsNew = false
    @State private var whatsNewText = ""
    @State private var whatsNewLocale = "zh-Hans"
    @State private var isSaving = false
    @State private var betaReviewStatus: BetaReviewStatus?
    @State private var isSubmittingReview = false
    @State private var reviewMessage: String?
    @State private var showExpireConfirm = false
    @State private var isExpiring = false
    @State private var expireMessage: String?

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
                            buildInfoCard(detail)
                            betaStateCard(detail)
                            betaReviewCard(detail)
                            localizationsCard(detail)
                            groupsCard
                            if detail.expired != true {
                                expireBuildCard
                            }
                        }
                        .padding(16)
                    }
                } else {
                    Text("加载失败")
                        .foregroundStyle(Color.dsMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("构建 \(build.displayVersion)")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .glassSheet(isPresented: $editingWhatsNew) {
                editWhatsNewSheet
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await loadData() }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            detail = try await service.getBuildDetail(buildId: build.id, accountId: accountId)
            betaReviewStatus = try? await service.getBetaReviewStatus(buildId: build.id, accountId: accountId)
        } catch {
            AppLogger.api.error("Build detail load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    // MARK: - Build Info

    private func buildInfoCard(_ d: BuildDetail) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dsAccentBlue.opacity(0.12))
                        .frame(width: 48, height: 48)
                    HIcon(AppIcon.hammer)
                        .font(.title3)
                        .foregroundStyle(Color.dsAccentBlue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(build.displayVersion)
                        .font(.headline)
                        .foregroundStyle(Color.dsText)
                    HStack(spacing: 6) {
                        Text(d.stateLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (d.processing_state == "VALID" ? Color.dsAccent : Color.dsMuted).opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(d.processing_state == "VALID" ? Color.dsAccent : Color.dsMuted)
                        if d.expired == true {
                            Text("已过期")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.dsAccentPink.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.dsAccentPink)
                        }
                    }
                }
                Spacer()
            }
            .padding(.bottom, 14)

            Divider().foregroundStyle(Color.dsBorder)

            VStack(spacing: 8) {
                if let appVer = build.app_version {
                    infoRow("App 版本", appVer)
                }
                infoRow("构建号", d.version ?? "-")
                if let platform = build.platform {
                    infoRow("平台", platform)
                }
                infoRow("上传时间", formatDate(d.uploaded_date))
                if let exp = d.expiration_date {
                    infoRow("过期时间", formatDate(exp))
                }
                infoRow("最低系统", d.min_os_version ?? "-")
                if d.auto_notify_enabled != nil {
                    infoRow("自动通知", d.auto_notify_enabled == true ? "开启" : "关闭")
                }
                if let audience = build.build_audience_type {
                    infoRow("受众类型", audienceLabel(audience))
                }
            }
            .padding(.top, 14)
        }
        .cardStyle()
    }

    private func formatDate(_ dateStr: String?) -> String {
        guard let s = dateStr else { return "-" }
        return s.toLocalDate()
    }

    private func audienceLabel(_ type: String) -> String {
        switch type {
        case "INTERNAL_ONLY": return "仅内部"
        case "APP_STORE_ELIGIBLE": return "App Store 可用"
        default: return type
        }
    }

    // MARK: - Beta State

    private func betaStateCard(_ d: BuildDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Beta 测试状态")

            VStack(spacing: 8) {
                if let ext = d.external_build_state {
                    HStack {
                        Text("外部测试")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        Text(d.externalStateLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(betaStateColor(ext))
                    }
                }
                if let int = d.internal_build_state {
                    HStack {
                        Text("内部测试")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        Text(internalStateLabel(int))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(betaStateColor(int))
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Beta Review

    private func betaReviewCard(_ d: BuildDetail) -> some View {
        let needsReview = d.external_build_state == "READY_FOR_BETA_SUBMISSION"
            || d.external_build_state == "WAITING_FOR_BETA_REVIEW"
            || d.external_build_state == "MISSING_EXPORT_COMPLIANCE"
            || betaReviewStatus == nil

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Beta 审核")

            VStack(spacing: 12) {
                if let status = betaReviewStatus {
                    HStack {
                        Text("审核状态")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        Text(status.stateLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(reviewStateColor(status.beta_review_state))
                    }
                }

                if let msg = reviewMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("成功") || msg.contains("已提交") ? Color.dsAccent : Color.dsAccentPink)
                }

                if needsReview && d.processing_state == "VALID" {
                    Button {
                        Task { await submitBetaReview() }
                    } label: {
                        HStack(spacing: 6) {
                            if isSubmittingReview {
                                ProgressView().tint(.white).controlSize(.small)
                            } else {
                                HIcon(AppIcon.paperplane)
                            }
                            Text("提交 Beta 审核")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmittingReview)

                    Text("外部测试组需要通过 Beta 审核后才能分发给测试员")
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }
            }
            .cardStyle()
        }
    }

    private func submitBetaReview() async {
        isSubmittingReview = true
        reviewMessage = nil
        do {
            try await service.submitForBetaReview(buildId: build.id, accountId: accountId)
            reviewMessage = "已成功提交 Beta 审核"
            betaReviewStatus = try? await service.getBetaReviewStatus(buildId: build.id, accountId: accountId)
            await loadData()
        } catch {
            reviewMessage = "提交失败: \(error.localizedDescription)"
        }
        isSubmittingReview = false
    }

    private func reviewStateColor(_ state: String?) -> Color {
        switch state {
        case "APPROVED": return .dsAccent
        case "IN_REVIEW", "WAITING_FOR_REVIEW": return .dsAccentOrange
        case "REJECTED": return .dsAccentPink
        default: return .dsMuted
        }
    }

    // MARK: - Localizations

    private func localizationsCard(_ d: BuildDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("测试内容 (What to Test)")
                Spacer()
                Button {
                    if let first = d.localizations?.first {
                        whatsNewText = first.whats_new ?? ""
                        whatsNewLocale = first.locale ?? "zh-Hans"
                    }
                    editingWhatsNew = true
                } label: {
                    HStack(spacing: 4) {
                        HIcon(AppIcon.pencil)
                            .font(.caption2)
                        Text("编辑")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.dsAccentBlue)
                }
            }

            if let locs = d.localizations, !locs.isEmpty {
                ForEach(locs) { loc in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(loc.locale ?? "未知语言")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.dsAccentPurple.opacity(0.1), in: Capsule())
                            .foregroundStyle(Color.dsAccentPurple)
                        Text(loc.whats_new ?? "（空）")
                            .font(.subheadline)
                            .foregroundStyle(loc.whats_new != nil ? Color.dsText : Color.dsMuted)
                    }
                    .cardStyle()
                }
            } else {
                Text("暂无测试内容，点击编辑添加")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .cardStyle()
            }
        }
    }

    // MARK: - Groups

    private var groupsCard: some View {
        let buildGroups = detail?.groups ?? []
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("已分发分组")

            if buildGroups.isEmpty {
                Text("此构建尚未分发到任何测试分组")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .cardStyle()
            } else {
                ForEach(buildGroups) { group in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill((group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange).opacity(0.1))
                                .frame(width: 32, height: 32)
                            HIcon(group.is_internal == true ? AppIcon.personGroup : AppIcon.globe)
                                .font(.caption)
                                .foregroundStyle(group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange)
                        }
                        Text(group.name ?? "未命名")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                        Spacer()
                        Text(group.is_internal == true ? "内部" : "外部")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange).opacity(0.1),
                                in: Capsule()
                            )
                            .foregroundStyle(group.is_internal == true ? Color.dsAccentBlue : Color.dsAccentOrange)
                    }
                    .cardStyle()
                }
            }
        }
    }

    // MARK: - Edit What's New Sheet

    private var editWhatsNewSheet: some View {
        NavigationStack {
            Form {
                Section("语言") {
                    Picker("语言", selection: $whatsNewLocale) {
                        Text("简体中文").tag("zh-Hans")
                        Text("English (US)").tag("en-US")
                        Text("繁體中文").tag("zh-Hant")
                        Text("日本語").tag("ja")
                        Text("한국어").tag("ko")
                    }
                }
                Section("测试内容") {
                    TextEditor(text: $whatsNewText)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("编辑测试内容")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { editingWhatsNew = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        isSaving = true
                        Task {
                            do {
                                try await service.updateBuildLocalization(
                                    buildId: build.id,
                                    accountId: accountId,
                                    whatsNew: whatsNewText,
                                    locale: whatsNewLocale
                                )
                                editingWhatsNew = false
                                await loadData()
                            } catch {
                                AppLogger.api.error("Save whats new failed: \(error.localizedDescription)")
                            }
                            isSaving = false
                        }
                    }
                    .disabled(whatsNewText.isEmpty || isSaving)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.dsText)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.dsText)
                .lineLimit(1)
        }
    }

    private func betaStateColor(_ state: String) -> Color {
        switch state {
        case "READY_FOR_BETA_TESTING", "IN_BETA_TESTING", "BETA_APPROVED":
            return .dsAccent
        case "PROCESSING":
            return .dsAccentOrange
        case "EXPIRED", "BETA_REJECTED", "PROCESSING_EXCEPTION", "FAILED":
            return .dsAccentPink
        default:
            return .dsAccentBlue
        }
    }

    private func internalStateLabel(_ state: String) -> String {
        switch state {
        case "PROCESSING": return "处理中"
        case "PROCESSING_EXCEPTION": return "处理异常"
        case "MISSING_EXPORT_COMPLIANCE": return "缺少出口合规"
        case "READY_FOR_BETA_TESTING": return "可测试"
        case "IN_BETA_TESTING": return "测试中"
        case "EXPIRED": return "已过期"
        default: return state
        }
    }

    // MARK: - Expire Build

    private var expireBuildCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("构建管理")

            VStack(spacing: 12) {
                if let msg = expireMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("成功") ? Color.dsAccent : Color.dsAccentPink)
                }

                Button {
                    showExpireConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        if isExpiring {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            HIcon(AppIcon.clock)
                        }
                        Text("设为过期")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(Color.dsAccentPink, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isExpiring)

                Text("过期后测试员将无法安装此构建版本，此操作不可撤销")
                    .font(.caption2)
                    .foregroundStyle(Color.dsMuted)
            }
            .cardStyle()
        }
        .alert("确认设为过期", isPresented: $showExpireConfirm) {
            Button("取消", role: .cancel) { }
            Button("确认过期", role: .destructive) {
                Task { await expireBuild() }
            }
        } message: {
            Text("构建版本 \(build.displayVersion) 过期后，所有测试员将无法再安装此版本。此操作不可撤销。")
        }
    }

    private func expireBuild() async {
        isExpiring = true
        expireMessage = nil
        do {
            try await service.expireBuild(buildId: build.id, accountId: accountId)
            expireMessage = "构建版本已成功设为过期"
            await loadData()
        } catch {
            expireMessage = "操作失败: \(error.localizedDescription)"
        }
        isExpiring = false
    }
}
