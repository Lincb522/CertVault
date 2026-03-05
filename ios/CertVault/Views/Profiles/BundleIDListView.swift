import SwiftUI
import HiconIcons

struct BundleIDListView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var showCreate = false
    @State private var itemToDelete: BundleIDItem?

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                DSEmptyState(
                    icon: AppIcon.account,
                    title: L10n.Device.noAccountTitle,
                    message: L10n.Device.noAccountMessage
                )
            } else if vm.bundleIds.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                DSEmptyState(
                    icon: AppIcon.bundleID,
                    title: L10n.BundleID.emptyTitle,
                    message: L10n.BundleID.emptyMessage,
                    actionTitle: L10n.BundleID.create
                ) { showCreate = true }
            } else {
                ScrollView {
                    VStack(spacing: DS.spacingMD) {
                        if vm.accounts.count > 1 {
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
                                .tint(Color.dsBrand)
                                .onChange(of: vm.selectedAccountId) { _ in
                                    Task { await vm.loadBundleIds() }
                                }
                            }
                            .padding(DS.spacingLG)
                            .cardStyle()
                            .padding(.horizontal, DS.spacingLG)
                        }

                        DSGroupedCard {
                            ForEach(vm.bundleIds) { item in
                                NavigationLink {
                                    BundleIDDetailView(
                                        bundleId: item,
                                        accountId: vm.selectedAccountId,
                                        onDelete: { try? await vm.deleteBundleId(id: item.id) }
                                    )
                                } label: {
                                    BundleIDRow(item: item)
                                }
                                .buttonStyle(.dsPressed)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                    } label: {
                                        Label { Text(L10n.delete) } icon: { HIcon(AppIcon.delete) }
                                    }
                                }

                                if item.id != vm.bundleIds.last?.id {
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
                .refreshable { await vm.loadBundleIds() }
            }
        }
        .navigationTitle("Bundle ID")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.bundleIds.isEmpty {
                LoadingView()
            }
        }
        .task { await vm.loadAccounts() }
        .sheet(isPresented: $showCreate) {
            CreateBundleIDView(vm: vm)
        }
        .alert(L10n.BundleID.deleteTitle, isPresented: .init(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button(L10n.delete, role: .destructive) {
                if let item = itemToDelete {
                    Task { try? await vm.deleteBundleId(id: item.id) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

// MARK: - Bundle ID Row

private struct BundleIDRow: View {
    let item: BundleIDItem

    var body: some View {
        DSRow(
            icon: AppIcon.bundleID,
            iconColor: .dsBlue,
            title: item.displayName,
            subtitle: item.identifier,
            trailing: nil,
            showChevron: true
        )
    }
}
