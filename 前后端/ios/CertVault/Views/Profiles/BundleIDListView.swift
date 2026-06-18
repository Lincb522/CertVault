import SwiftUI
import HiconIcons

struct BundleIDListView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var showCreate = false
    @State private var itemToDelete: BundleIDItem?

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                EmptyStateView(
                    icon: AppIcon.account,
                    title: L10n.Device.noAccountTitle,
                    message: L10n.Device.noAccountMessage
                )
            } else if vm.bundleIds.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                EmptyStateView(
                    icon: AppIcon.bundleID,
                    title: L10n.BundleID.emptyTitle,
                    message: L10n.BundleID.emptyMessage,
                    actionTitle: L10n.BundleID.create
                ) { showCreate = true }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if vm.accounts.count > 1 {
                            HStack {
                                Text(L10n.account)
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
                                    Task { await vm.loadBundleIds() }
                                }
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 12)
                            .padding(.horizontal, 16)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(Array(vm.bundleIds.enumerated()), id: \.element.id) { index, item in
                                NavigationLink {
                                    BundleIDDetailView(
                                        bundleId: item,
                                        accountId: vm.selectedAccountId,
                                        onDelete: { try? await vm.deleteBundleId(id: item.id) }
                                    )
                                } label: {
                                    HStack(spacing: 14) {
                                        HIcon(AppIcon.bundleID)
                                            .font(.body)
                                            .foregroundStyle(Color.dsAccentCyan)
                                            .frame(width: 40, height: 40)
                                            .background(Color.dsAccentCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.displayName)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.dsText)
                                                .lineLimit(1)
                                            Text(item.identifier ?? "")
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Color.dsMuted)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        HIcon(AppIcon.chevronRight)
                                            .font(.caption)
                                            .foregroundStyle(Color.dsMuted.opacity(0.5))
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                    } label: {
                                        Label(L10n.delete, systemImage: "trash")
                                    }
                                }

                                if index < vm.bundleIds.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .glassCard(cornerRadius: 14)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
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
        .glassSheet(isPresented: $showCreate) {
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
