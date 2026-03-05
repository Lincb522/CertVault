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
                                        Task { await vm.loadBundleIds() }
                                    }
                                }
                                .padding(.vertical, DS.spacingMD)
                                .padding(.horizontal, DS.spacingLG)
                            }
                            .padding(.horizontal, DS.spacingLG)
                        }

                        DSGroupedCard {
                            ForEach(Array(vm.bundleIds.enumerated()), id: \.element.id) { index, item in
                                NavigationLink {
                                    BundleIDDetailView(
                                        bundleId: item,
                                        accountId: vm.selectedAccountId,
                                        onDelete: { try? await vm.deleteBundleId(id: item.id) }
                                    )
                                } label: {
                                    DSRow(
                                        icon: AppIcon.bundleID,
                                        iconColor: .dsCyan,
                                        title: item.displayName,
                                        subtitle: item.identifier ?? "",
                                        useGradientIcon: true
                                    )
                                }
                                .buttonStyle(.dsPressed)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                    } label: {
                                        Label(L10n.delete, systemImage: "trash")
                                    }
                                }

                                if index < vm.bundleIds.count - 1 {
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
