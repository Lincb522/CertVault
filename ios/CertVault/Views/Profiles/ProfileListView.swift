import SwiftUI
import HiconIcons

struct ProfileListView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var showCreate = false
    @State private var profileToDelete: Profile?
    @ObservedObject private var downloadService = FileDownloadService.shared

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                EmptyStateView(
                    icon: AppIcon.account,
                    title: "暂无开发者账号",
                    message: "请先在「账号」页面添加 Apple Developer API Key"
                )
            } else if vm.profiles.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                EmptyStateView(
                    icon: AppIcon.profile,
                    title: "暂无描述文件",
                    message: "创建描述文件以进行签名分发",
                    actionTitle: "创建描述文件"
                ) { showCreate = true }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if vm.accounts.count > 1 {
                            HStack {
                                Text("账号")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsMuted)
                                Spacer()
                                Picker("", selection: $vm.selectedAccountId) {
                                    ForEach(vm.accounts) { acc in
                                        Text(acc.displayName).tag(acc.id)
                                    }
                                }
                                .tint(Color.dsAccentBlue)
                                .onChange(of: vm.selectedAccountId) { _ in
                                    Task { await vm.loadAll() }
                                }
                            }
                            .padding(14)
                            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.dsBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(Array(vm.profiles.enumerated()), id: \.element.id) { index, profile in
                                NavigationLink {
                                    ProfileDetailView(profileId: profile.id) {
                                        try? await vm.deleteProfile(id: profile.id)
                                    }
                                } label: {
                                    ProfileRow(profile: profile) {
                                        Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                                    } label: {
                                        Label { Text("下载") } icon: { HIcon(AppIcon.download) }
                                    }
                                    Button(role: .destructive) {
                                        profileToDelete = profile
                                    } label: {
                                        Label { Text("删除") } icon: { HIcon(AppIcon.delete) }
                                    }
                                }

                                if index < vm.profiles.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.dsBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .pageBackground()
                .refreshable { await vm.loadAll() }
            }
        }
        .navigationTitle("描述文件")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.profiles.isEmpty {
                LoadingView()
            }
        }
        .task { await vm.loadAccounts() }
        .sheet(isPresented: $showCreate) {
            CreateProfileView(vm: vm)
        }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("确认删除", isPresented: .init(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let p = profileToDelete {
                    Task { try? await vm.deleteProfile(id: p.id) }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HIcon(AppIcon.profile)
                .font(.body)
                .foregroundStyle(Color.dsAccentOrange)
                .frame(width: 40, height: 40)
                .background(Color.dsAccentOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(profile.type ?? "")
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                    if profile.has_file == true {
                        StatusBadge("可下载", color: .dsAccent)
                    }
                }
            }

            Spacer()

            if profile.has_file == true {
                Button(action: onDownload) {
                    HIcon(AppIcon.docDownload)
                        .font(.body)
                        .foregroundStyle(Color.dsAccentBlue)
                }
                .buttonStyle(.borderless)
            }

            HIcon(AppIcon.chevronRight)
                .font(.caption)
                .foregroundStyle(Color.dsMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}
