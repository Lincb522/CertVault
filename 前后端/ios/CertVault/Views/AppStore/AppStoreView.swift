import SwiftUI
import HiconIcons

struct AppStoreView: View {
    @StateObject private var vm = AppStoreViewModel()
    @State private var showCreateVersion = false
    @State private var selectedVersion: AppStoreVersion?
    @State private var showVersionDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                accountAppPicker

                if vm.isLoading {
                    LoadingView().frame(height: 200)
                } else if vm.versions.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.star,
                        title: "暂无版本",
                        message: "选择应用后查看 App Store 版本"
                    )
                } else {
                    versionsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle("App Store 版本")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreateVersion = true } label: {
                    HIcon(AppIcon.add).font(.body)
                }
            }
        }
        .glassSheet(isPresented: $showCreateVersion) {
            CreateVersionSheet(vm: vm)
        }
        .glassSheet(isPresented: $showVersionDetail) {
            if let ver = selectedVersion {
                VersionDetailSheet(vm: vm, version: ver)
            }
        }
        .task { await vm.loadAccounts() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.dsAccentOrange, .dsAccentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                HIcon(AppIcon.star)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("App Store 版本")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text("管理 App Store 版本和提交审核")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            Spacer()
            if !vm.versions.isEmpty {
                Text("\(vm.versions.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsAccentOrange)
            }
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
                .onChange(of: vm.selectedAccountId) {
                    Task {
                        await vm.loadApps()
                        await vm.loadVersions()
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
                    Text("请选择应用").tag("")
                    ForEach(vm.apps) { app in Text(app.displayName).tag(app.id) }
                }
                .tint(Color.dsAccentBlue)
                .onChange(of: vm.selectedAppId) {
                    Task { await vm.loadVersions() }
                }
            }
            .padding(.top, 10)
        }
        .cardStyle()
    }

    // MARK: - Versions

    private var versionsSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(vm.versions) { ver in
                versionCard(ver)
            }
        }
    }

    private func versionCard(_ ver: AppStoreVersion) -> some View {
        Button {
            selectedVersion = ver
            showVersionDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(stateColor(ver.state).opacity(0.12))
                            .frame(width: 44, height: 44)
                        HIcon(stateIcon(ver.state))
                            .font(.callout)
                            .foregroundStyle(stateColor(ver.state))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("v\(ver.version ?? "-")")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.dsText)
                                .lineLimit(1)
                            Text(ver.displayState)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(stateColor(ver.state).opacity(0.12), in: Capsule())
                                .foregroundStyle(stateColor(ver.state))
                                .lineLimit(1)
                        }

                        HStack(spacing: 10) {
                            if let platform = ver.platform {
                                HStack(spacing: 3) {
                                    HIcon(AppIcon.iphone)
                                        .font(.system(size: 10))
                                    Text(platform)
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.dsMuted)
                                .lineLimit(1)
                            }
                            if let rt = ver.release_type {
                                HStack(spacing: 3) {
                                    HIcon(AppIcon.arrowUp)
                                        .font(.system(size: 10))
                                    Text(releaseTypeLabel(rt))
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.dsMuted)
                                .lineLimit(1)
                            }
                            if let date = ver.created_date {
                                Spacer()
                                Text(date)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dsMuted)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    HIcon(AppIcon.chevronRight)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                }

                if ver.state == "PREPARE_FOR_SUBMISSION" {
                    Button {
                        Task { try? await vm.submitForReview(versionId: ver.id) }
                    } label: {
                        HStack(spacing: 6) {
                            HIcon(AppIcon.paperplane)
                                .font(.caption2)
                            Text("提交审核")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(
                                colors: [.dsAccentBlue, .dsAccentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private func stateColor(_ state: String?) -> Color {
        switch state {
        case "READY_FOR_SALE": return .dsAccent
        case "WAITING_FOR_REVIEW", "IN_REVIEW": return .dsAccentOrange
        case "PREPARE_FOR_SUBMISSION": return .dsAccentBlue
        case "REJECTED": return .dsAccentPink
        case "DEVELOPER_REMOVED_FROM_SALE": return .dsMuted
        default: return .dsMuted
        }
    }

    private func stateIcon(_ state: String?) -> UIImage {
        switch state {
        case "READY_FOR_SALE": return AppIcon.check
        case "WAITING_FOR_REVIEW": return AppIcon.clock
        case "IN_REVIEW": return AppIcon.info
        case "PREPARE_FOR_SUBMISSION": return AppIcon.info
        case "REJECTED": return AppIcon.close
        default: return AppIcon.info
        }
    }

    private func releaseTypeLabel(_ rt: String) -> String {
        switch rt {
        case "MANUAL": return "手动发布"
        case "AFTER_APPROVAL": return "自动发布"
        case "SCHEDULED": return "定时发布"
        default: return rt
        }
    }
}

// MARK: - Create Version Sheet

private struct CreateVersionSheet: View {
    @ObservedObject var vm: AppStoreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var version = ""
    @State private var platform = "IOS"
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("版本信息") {
                    TextField("版本号 (如 1.0.0)", text: $version)
                        .keyboardType(.decimalPad)
                    Picker("平台", selection: $platform) {
                        Text("iOS").tag("IOS")
                        Text("macOS").tag("MAC_OS")
                        Text("tvOS").tag("TV_OS")
                    }
                }
            }
            .navigationTitle("新建版本")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        isCreating = true
                        Task {
                            try? await vm.createVersion(version: version, platform: platform)
                            dismiss()
                        }
                    }
                    .disabled(version.isEmpty || isCreating)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.medium])
    }
}

// MARK: - Version Detail Sheet

private struct VersionDetailSheet: View {
    @ObservedObject var vm: AppStoreViewModel
    let version: AppStoreVersion
    @Environment(\.dismiss) private var dismiss
    @State private var detail: AppStoreVersion?
    @State private var isLoading = true
    @State private var editingLocalization: AppStoreLocalization?
    @State private var versionBuild: VersionBuildInfo?
    @State private var phasedRelease: PhasedReleaseInfo?
    @State private var showBuildPicker = false
    @State private var showReleaseTypePicker = false
    @State private var builds: [AppBuild] = []
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    ScrollView {
                        VStack(spacing: 16) {
                            versionInfoCard(detail)
                            buildAssociationCard
                            releaseManagementCard(detail)
                            phasedReleaseCard

                            if let locs = detail.localizations, !locs.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    sectionHeader("本地化")
                                    ForEach(locs) { loc in
                                        localizationCard(loc)
                                    }
                                }
                            }

                            if detail.state == "PREPARE_FOR_SUBMISSION" {
                                submitButton
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("版本详情")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await loadDetail() } } label: {
                        HIcon(AppIcon.arrowClockwise)
                    }
                }
            }
            .glassSheet(item: $editingLocalization) { loc in
                EditLocalizationSheet(vm: vm, localization: loc) {
                    Task { await loadDetail() }
                }
            }
            .glassSheet(isPresented: $showBuildPicker) {
                BuildPickerSheet(builds: builds, currentBuildId: versionBuild?.id) { selectedBuild in
                    Task {
                        do {
                            try await vm.setVersionBuild(versionId: version.id, buildId: selectedBuild?.id)
                            await loadDetail()
                        } catch {
                            actionError = error.localizedDescription
                        }
                    }
                }
            }
            .alert("操作失败", isPresented: .init(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("好的") { actionError = nil }
            } message: {
                Text(actionError ?? "未知错误")
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await loadDetail() }
    }

    private func loadDetail() async {
        isLoading = true
        do {
            async let d = vm.getVersionDetail(id: version.id)
            async let b = vm.getVersionBuild(versionId: version.id)
            async let p = vm.getPhasedRelease(versionId: version.id)
            async let allBuilds = vm.loadBuilds()
            detail = try await d
            versionBuild = try await b
            phasedRelease = try await p
            builds = try await allBuilds
        } catch {
            detail = version
        }
        isLoading = false
    }

    // MARK: - Build Association

    private var buildAssociationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("关联构建版本")

            Button { showBuildPicker = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.dsAccentBlue.opacity(0.1))
                            .frame(width: 40, height: 40)
                        HIcon(AppIcon.hammer)
                            .font(.callout)
                            .foregroundStyle(Color.dsAccentBlue)
                    }

                    if let vb = versionBuild {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("v\(vb.version ?? "-")")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dsText)
                            if let date = vb.uploaded_date {
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
                            }
                        }
                    } else {
                        Text("点击选择构建版本")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                    }

                    Spacer()

                    HIcon(AppIcon.chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dsMuted.opacity(0.4))
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Release Management

    private func releaseManagementCard(_ ver: AppStoreVersion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("发布设置")

            VStack(spacing: 0) {
                HStack {
                    Text("发布方式")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                    Spacer()

                    if ver.state == "PREPARE_FOR_SUBMISSION" || ver.state == "WAITING_FOR_REVIEW" {
                        Button {
                            showReleaseTypePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(ver.releaseTypeLabel)
                                    .font(.subheadline.weight(.medium))
                                HIcon(AppIcon.down)
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(Color.dsAccentBlue)
                        }
                        .confirmationDialog("选择发布方式", isPresented: $showReleaseTypePicker) {
                            Button("手动发布") {
                                Task {
                                    do { try await vm.updateReleaseType(versionId: ver.id, releaseType: "MANUAL") }
                                    catch { actionError = error.localizedDescription }
                                    await loadDetail()
                                }
                            }
                            Button("审核通过后自动发布") {
                                Task {
                                    do { try await vm.updateReleaseType(versionId: ver.id, releaseType: "AFTER_APPROVAL") }
                                    catch { actionError = error.localizedDescription }
                                    await loadDetail()
                                }
                            }
                            Button("取消", role: .cancel) {}
                        }
                    } else {
                        Text(ver.releaseTypeLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                    }
                }
                .padding(.bottom, 12)

                Divider().foregroundStyle(Color.dsBorder)

                HStack {
                    Text("平台")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsMuted)
                    Spacer()
                    Text(ver.platform ?? "-")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
                }
                .padding(.top, 12)

                if let date = ver.created_date {
                    Divider().foregroundStyle(Color.dsBorder).padding(.vertical, 12)
                    HStack {
                        Text("创建时间")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        Text(date)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Phased Release

    private var phasedReleaseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("分阶段发布")

            if let pr = phasedRelease {
                VStack(spacing: 8) {
                    HStack {
                        Text("状态")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        Text(pr.stateLabel)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(phasedColor(pr.state).opacity(0.1), in: Capsule())
                            .foregroundStyle(phasedColor(pr.state))
                    }

                    if let day = pr.current_day_number {
                        HStack {
                            Text("当前天数")
                                .font(.subheadline)
                                .foregroundStyle(Color.dsMuted)
                            Spacer()
                            Text("第 \(day) / 7 天")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                        }

                        ProgressView(value: Double(day), total: 7)
                            .tint(Color.dsAccent)
                    }

                    Divider().foregroundStyle(Color.dsBorder)

                    HStack(spacing: 10) {
                        if pr.state == "ACTIVE" {
                            Button {
                                Task {
                                    do { try await vm.updatePhasedRelease(id: pr.id, state: "PAUSED") }
                                    catch { actionError = error.localizedDescription }
                                    await loadDetail()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    HIcon(AppIcon.pause)
                                        .font(.caption2)
                                    Text("暂停")
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(Color.dsAccentOrange)
                                .background(Color.dsAccentOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }

                        if pr.state == "PAUSED" {
                            Button {
                                Task {
                                    do { try await vm.updatePhasedRelease(id: pr.id, state: "ACTIVE") }
                                    catch { actionError = error.localizedDescription }
                                    await loadDetail()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    HIcon(AppIcon.play)
                                        .font(.caption2)
                                    Text("恢复")
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(Color.dsAccent)
                                .background(Color.dsAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }

                        if pr.state == "ACTIVE" || pr.state == "PAUSED" {
                            Button(role: .destructive) {
                                Task {
                                    do { try await vm.deletePhasedRelease(id: pr.id) }
                                    catch { actionError = error.localizedDescription }
                                    await loadDetail()
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    HIcon(AppIcon.xmark)
                                        .font(.caption2)
                                    Text("取消")
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(Color.dsAccentPink)
                                .background(Color.dsAccentPink.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .cardStyle()
            } else {
                Button {
                    Task {
                        do { try await vm.createPhasedRelease(versionId: version.id) }
                        catch { actionError = error.localizedDescription }
                        await loadDetail()
                    }
                } label: {
                    HStack(spacing: 8) {
                        HIcon(AppIcon.chart)
                            .font(.caption)
                        Text("启用分阶段发布")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.dsAccentBlue)
                    .background(Color.dsAccentBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.dsAccentBlue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task {
                do {
                    try await vm.submitForReview(versionId: version.id)
                    await loadDetail()
                } catch {
                    actionError = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 8) {
                HIcon(AppIcon.paperplane)
                    .font(.subheadline)
                Text("提交审核")
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [.dsAccentBlue, .dsAccentPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info Card

    private func versionInfoCard(_ ver: AppStoreVersion) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(stateColor(ver.state).opacity(0.12))
                    .frame(width: 48, height: 48)
                HIcon(stateIcon(ver.state))
                    .font(.title3)
                    .foregroundStyle(stateColor(ver.state))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("v\(ver.version ?? "-")")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(ver.displayState)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stateColor(ver.state).opacity(0.12), in: Capsule())
                    .foregroundStyle(stateColor(ver.state))
            }
            Spacer()
        }
        .cardStyle()
    }

    private func localizationCard(_ loc: AppStoreLocalization) -> some View {
        Button { editingLocalization = loc } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dsAccentBlue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    HIcon(AppIcon.globe)
                        .font(.callout)
                        .foregroundStyle(Color.dsAccentBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.locale ?? "未知")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsText)
                    if let wn = loc.whats_new, !wn.isEmpty {
                        Text(wn)
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                HIcon(AppIcon.edit)
                    .font(.caption)
                    .foregroundStyle(Color.dsAccentBlue)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.dsText)
    }

    private func stateColor(_ state: String?) -> Color {
        switch state {
        case "READY_FOR_SALE": return .dsAccent
        case "WAITING_FOR_REVIEW", "IN_REVIEW": return .dsAccentOrange
        case "PREPARE_FOR_SUBMISSION": return .dsAccentBlue
        case "REJECTED": return .dsAccentPink
        default: return .dsMuted
        }
    }

    private func stateIcon(_ state: String?) -> UIImage {
        switch state {
        case "READY_FOR_SALE": return AppIcon.check
        case "WAITING_FOR_REVIEW": return AppIcon.clock
        case "IN_REVIEW": return AppIcon.info
        case "PREPARE_FOR_SUBMISSION": return AppIcon.info
        case "REJECTED": return AppIcon.close
        default: return AppIcon.info
        }
    }

    private func phasedColor(_ state: String?) -> Color {
        switch state {
        case "ACTIVE": return .dsAccent
        case "PAUSED": return .dsAccentOrange
        case "COMPLETE": return .dsAccentBlue
        default: return .dsMuted
        }
    }
}

// MARK: - Build Picker Sheet

private struct BuildPickerSheet: View {
    let builds: [AppBuild]
    let currentBuildId: String?
    let onSelect: (AppBuild?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if builds.isEmpty {
                    Text("暂无可用构建版本")
                        .foregroundStyle(Color.dsMuted)
                } else {
                    ForEach(builds) { build in
                        Button {
                            onSelect(build)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("v\(build.version ?? "-")")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.dsText)
                                    if let date = build.uploaded_date {
                                        Text(date)
                                            .font(.caption)
                                            .foregroundStyle(Color.dsMuted)
                                    }
                                }
                                Spacer()
                                StatusBadge(build.stateLabel, color: build.processing_state == "VALID" ? .dsAccent : .dsMuted)
                                if build.id == currentBuildId {
                                    HIcon(AppIcon.check)
                                        .foregroundStyle(Color.dsAccent)
                                }
                            }
                        }
                    }

                    if currentBuildId != nil {
                        Button(role: .destructive) {
                            onSelect(nil)
                            dismiss()
                        } label: {
                            HStack {
                                HIcon(AppIcon.close)
                                Text("取消关联")
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择构建版本")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .sheetStyle()
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit Localization Sheet

private struct EditLocalizationSheet: View {
    @ObservedObject var vm: AppStoreViewModel
    let localization: AppStoreLocalization
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var whatsNew: String = ""
    @State private var desc: String = ""
    @State private var keywords: String = ""
    @State private var isSaving = false
    @State private var showTemplateList = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Button { showTemplateList = true } label: {
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

                        Button { showSaveTemplate = true } label: {
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("更新说明") {
                    TextEditor(text: $whatsNew)
                        .frame(minHeight: 80)
                }
                Section("描述") {
                    TextEditor(text: $desc)
                        .frame(minHeight: 80)
                }
                Section("关键词") {
                    TextField("关键词（逗号分隔）", text: $keywords)
                }
            }
            .navigationTitle("编辑本地化 - \(localization.locale ?? "")")
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        isSaving = true
                        Task {
                            try? await vm.updateLocalization(
                                id: localization.id,
                                whatsNew: whatsNew.isEmpty ? nil : whatsNew,
                                description: desc.isEmpty ? nil : desc,
                                keywords: keywords.isEmpty ? nil : keywords
                            )
                            onSaved()
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .glassSheet(isPresented: $showTemplateList) {
                TemplatePickerSheet(type: .appStore) { template in
                    whatsNew = template.whatsNew ?? ""
                    desc = template.desc ?? ""
                    keywords = template.keywords ?? ""
                }
            }
            .alert("保存为模版", isPresented: $showSaveTemplate) {
                TextField("模版名称", text: $templateName)
                Button("保存") { saveAsTemplate() }
                Button("取消", role: .cancel) { templateName = "" }
            } message: {
                Text("为当前填写内容命名，方便下次快速使用")
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .onAppear {
            whatsNew = localization.whats_new ?? ""
            desc = localization.description ?? ""
            keywords = localization.keywords ?? ""
        }
    }

    private func saveAsTemplate() {
        guard !templateName.isEmpty else { return }
        let template = SubmitTemplate(
            name: templateName,
            type: .appStore,
            locale: localization.locale,
            whatsNew: whatsNew.isEmpty ? nil : whatsNew,
            desc: desc.isEmpty ? nil : desc,
            keywords: keywords.isEmpty ? nil : keywords
        )
        try? DatabaseManager.shared.saveTemplate(template)
        templateName = ""
    }
}
