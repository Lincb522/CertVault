import SwiftUI
import HiconIcons

struct AppListView: View {
    @StateObject private var vm = AppListViewModel()
    @State private var selectedApp: AppItem?
    @State private var showBuilds = false
    @State private var showVersions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                accountPicker

                if let error = vm.errorMessage, !vm.isLoading {
                    errorCard(error)
                }

                if vm.isLoading {
                    LoadingView().frame(height: 200)
                } else if vm.apps.isEmpty && vm.errorMessage == nil {
                    EmptyStateView(
                        icon: AppIcon.category,
                        title: "暂无应用",
                        message: "在所选账号下未找到 App Store Connect 应用"
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.apps) { app in
                            appCard(app)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle("应用管理")
        .sheet(isPresented: $showBuilds) {
            if let app = selectedApp {
                BuildListSheet(vm: vm, app: app)
            }
        }
        .sheet(isPresented: $showVersions) {
            if let app = selectedApp {
                VersionListSheet(vm: vm, app: app)
            }
        }
        .task { await vm.loadAccounts() }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HIcon(AppIcon.warning)
                    .foregroundStyle(Color.dsAccentOrange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.dsText)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            Button {
                Task { await vm.loadApps() }
            } label: {
                HStack(spacing: 6) {
                    HIcon(AppIcon.arrowClockwise)
                    Text("重试")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .cardStyle()
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentGradient)
                    .frame(width: 50, height: 50)
                HIcon(AppIcon.category)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("应用管理")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text("查看和管理 App Store Connect 中的应用")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            Spacer()
            if !vm.apps.isEmpty {
                Text("\(vm.apps.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsAccentBlue)
            }
        }
        .cardStyle()
    }

    private var accountPicker: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.dsAccentBlue.opacity(0.14))
                    .frame(width: 42, height: 42)
                HIcon(AppIcon.account)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.dsAccentBlue)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("账号")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.dsMuted)
                Picker("账号", selection: $vm.selectedAccountId) {
                    Text("请选择账号").tag("")
                    ForEach(vm.accounts) { acc in
                        Text(acc.displayName).tag(acc.id)
                    }
                }
                .tint(Color.dsAccentBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .frame(minHeight: 78)
        .onChange(of: vm.selectedAccountId) { _ in
            vm.onAccountChanged()
        }
        .cardStyle()
    }

    private func appCard(_ app: AppItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: gradientForApp(app),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Text(String(app.displayName.prefix(1)))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dsText)
                        .lineLimit(1)
                    if let bid = app.bundle_id {
                        Text(bid)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.dsMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            if app.sku != nil || app.primary_locale != nil {
                HStack(spacing: 8) {
                    if let sku = app.sku {
                        chipView(icon: AppIcon.tag, text: sku, color: .dsAccentBlue)
                    }
                    if let locale = app.primary_locale {
                        chipView(icon: AppIcon.globe, text: locale, color: .dsAccentPurple)
                    }
                    Spacer()
                }
            }

            Divider().foregroundStyle(Color.dsBorder)

            HStack(spacing: 10) {
                Button {
                    selectedApp = app
                    showBuilds = true
                } label: {
                    HStack(spacing: 6) {
                        HIcon(AppIcon.hammer)
                            .font(.caption2)
                        Text("构建版本")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color.dsAccentBlue)
                    .background(Color.dsAccentBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.dsAccentBlue.opacity(0.15), lineWidth: 1)
                    )
                }

                Button {
                    selectedApp = app
                    showVersions = true
                } label: {
                    HStack(spacing: 6) {
                        HIcon(AppIcon.clock)
                            .font(.caption2)
                        Text("版本历史")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color.dsAccentPurple)
                    .background(Color.dsAccentPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.dsAccentPurple.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
        .cardStyle()
    }

    private func chipView(icon: UIImage, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            HIcon(icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: Capsule())
    }

    private func gradientForApp(_ app: AppItem) -> [Color] {
        let hash = abs(app.displayName.hashValue)
        let pairs: [[Color]] = [
            [.dsAccentBlue, .dsAccentPurple],
            [.dsAccentPurple, .dsAccentPink],
            [.dsAccentBlue, .dsAccentCyan],
            [.dsAccentOrange, .dsAccentPink],
            [.dsAccent, .dsAccentCyan],
        ]
        return pairs[hash % pairs.count]
    }
}

// MARK: - Build List Sheet

private struct BuildListSheet: View {
    @ObservedObject var vm: AppListViewModel
    let app: AppItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingBuilds {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    VStack(spacing: 16) {
                        HIcon(AppIcon.warning)
                            .font(.largeTitle)
                            .foregroundStyle(Color.dsAccentOrange)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(Color.dsText)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            Task { await vm.loadBuilds(appId: app.id) }
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.dsAccentBlue, in: Capsule())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if vm.builds.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.info,
                        title: "暂无构建版本",
                        message: "该应用暂时没有上传的构建版本"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.builds) { build in
                                buildRow(build)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .pageBackground()
            .navigationTitle("构建版本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task { await vm.loadBuilds(appId: app.id) }
    }

    private func buildRow(_ build: AppBuild) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dsAccentBlue.opacity(0.1))
                    .frame(width: 40, height: 40)
                HIcon(AppIcon.hammer)
                    .font(.callout)
                    .foregroundStyle(Color.dsAccentBlue)
            }

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

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(build.stateLabel, color: build.processing_state == "VALID" ? .dsAccent : .dsMuted)
                if build.expired == true {
                    Text("已过期")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.dsAccentPink)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Version List Sheet

private struct VersionListSheet: View {
    @ObservedObject var vm: AppListViewModel
    let app: AppItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingVersions {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.versions.isEmpty {
                    EmptyStateView(
                        icon: AppIcon.info,
                        title: "暂无版本历史",
                        message: "该应用暂时没有 App Store 版本记录"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.versions) { ver in
                                versionRow(ver)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .pageBackground()
            .navigationTitle("版本历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task { await vm.loadVersions(appId: app.id) }
    }

    private func versionRow(_ ver: AppVersion) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stateColor(ver.state).opacity(0.1))
                    .frame(width: 40, height: 40)
                HIcon(AppIcon.clock)
                    .font(.callout)
                    .foregroundStyle(stateColor(ver.state))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("v\(ver.version ?? "-")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dsText)
                if let date = ver.created_date {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(ver.displayState)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(stateColor(ver.state).opacity(0.12), in: Capsule())
                    .foregroundStyle(stateColor(ver.state))
                if let rt = ver.release_type {
                    Text(rt)
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted)
                }
            }
        }
        .cardStyle()
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
}
