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
                DSEmptyState(
                    icon: AppIcon.account,
                    title: L10n.Profile.noAccountTitle,
                    message: L10n.Profile.noAccountMessage
                )
            } else if vm.profiles.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                DSEmptyState(
                    icon: AppIcon.profile,
                    title: L10n.Profile.emptyTitle,
                    message: L10n.Profile.emptyMessage,
                    actionTitle: L10n.Profile.create
                ) { showCreate = true }
            } else {
                ScrollView {
                    VStack(spacing: DS.spacingMD) {
                        if vm.accounts.count > 1 {
                            DSGroupedCard {
                                HStack {
                                    Text(L10n.account)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsTextSecondary)
                                    Spacer()
                                    Picker("", selection: $vm.selectedAccountId) {
                                        ForEach(vm.accounts) { acc in
                                            Text(acc.displayName).tag(acc.id)
                                        }
                                    }
                                    .tint(Color.dsBlue)
                                    .onChange(of: vm.selectedAccountId) { _ in
                                        Task { await vm.loadAll() }
                                    }
                                }
                                .padding(.vertical, DS.spacingMD)
                                .padding(.horizontal, DS.spacingLG)
                            }
                            .padding(.horizontal, DS.spacingLG)
                        }

                        DSGroupedCard {
                            ForEach(Array(vm.profiles.enumerated()), id: \.element.id) { index, profile in
                                NavigationLink {
                                    ProfileDetailView(profileId: profile.id) {
                                        try? await vm.deleteProfile(id: profile.id)
                                    }
                                } label: {
                                    DSRow(
                                        icon: AppIcon.profile,
                                        iconColor: .dsOrange,
                                        title: profile.displayName,
                                        subtitle: Localized.profileType(profile.type ?? ""),
                                        trailing: profileTrailing(profile: profile),
                                        useGradientIcon: true
                                    )
                                }
                                .buttonStyle(.dsPressed)
                                .contextMenu {
                                    Button {
                                        Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                                    } label: {
                                        Label { Text(L10n.download) } icon: { HIcon(AppIcon.download) }
                                    }
                                    Button(role: .destructive) {
                                        profileToDelete = profile
                                    } label: {
                                        Label { Text(L10n.delete) } icon: { HIcon(AppIcon.delete) }
                                    }
                                }

                                if index < vm.profiles.count - 1 {
                                    DSDivider()
                                }
                            }
                        }
                        .padding(.horizontal, DS.spacingLG)
                    }
                    .padding(.top, DS.spacingSM)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .refreshable { await vm.loadAll() }
            }
        }
        .navigationTitle(L10n.Profile.title)
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
        .alert(L10n.Profile.deleteTitle, isPresented: .init(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        )) {
            Button(L10n.delete, role: .destructive) {
                if let p = profileToDelete {
                    Task { try? await vm.deleteProfile(id: p.id) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private func profileTrailing(profile: Profile) -> AnyView? {
        guard profile.has_file == true else { return nil }
        return AnyView(
            HStack(spacing: DS.spacingSM) {
                DSBadge(text: L10n.Profile.downloadable, color: .dsGreen)
                Button {
                    Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                } label: {
                    HIcon(AppIcon.docDownload)
                        .font(.body)
                        .foregroundStyle(Color.dsBlue)
                }
                .buttonStyle(.borderless)
            }
        )
    }
}
