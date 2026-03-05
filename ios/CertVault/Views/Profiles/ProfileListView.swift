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
                    VStack(spacing: DS.spacingLG) {
                        if vm.accounts.count > 1 {
                            accountPicker
                                .padding(.horizontal, DS.spacingLG)
                        }

                        DSGroupedCard {
                            ForEach(vm.profiles) { profile in
                                NavigationLink {
                                    ProfileDetailView(profileId: profile.id) {
                                        try? await vm.deleteProfile(id: profile.id)
                                    }
                                } label: {
                                    ProfileRow(profile: profile) {
                                        Task { await downloadService.download(endpoint: "/profiles/\(profile.id)/download") }
                                    }
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

                                if profile.id != vm.profiles.last?.id {
                                    DSDivider(leadingPadding: 56)
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
                .buttonStyle(.dsPressed)
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

    @ViewBuilder
    private var accountPicker: some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.account)
                .font(.callout)
                .foregroundStyle(Color.dsBlue)
                .frame(width: 20)

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
        .padding(DS.spacingMD)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusLG))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusLG)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }
}

// MARK: - Profile Row

private struct ProfileRow: View {
    let profile: Profile
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.profile)
                .font(.callout)
                .foregroundStyle(Color.dsOrange)
                .frame(width: 32, height: 32)
                .background(Color.dsOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                HStack(spacing: DS.spacingSM) {
                    Text(Localized.profileType(profile.type ?? ""))
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                    if profile.has_file == true {
                        DSBadge(text: L10n.Profile.downloadable, color: .dsGreen)
                    }
                }
            }

            Spacer()

            if profile.has_file == true {
                Button(action: onDownload) {
                    HIcon(AppIcon.docDownload)
                        .font(.callout)
                        .foregroundStyle(Color.dsBlue)
                }
                .buttonStyle(.borderless)
            }

            HIcon(AppIcon.chevronRight)
                .font(.caption2)
                .foregroundStyle(Color.dsTextTertiary)
        }
        .padding(.vertical, DS.spacingMD)
        .padding(.horizontal, DS.spacingLG)
        .frame(minHeight: DS.minTouchTarget)
        .contentShape(Rectangle())
    }
}
