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
                    title: "暂无开发者账号",
                    message: "请先在「账号」页面添加 Apple Developer API Key"
                )
            } else if vm.bundleIds.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                EmptyStateView(
                    icon: AppIcon.bundleID,
                    title: "暂无 Bundle ID",
                    message: "创建 Bundle ID 用于应用签名",
                    actionTitle: "创建 Bundle ID"
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
                                    Task { await vm.loadBundleIds() }
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
                            ForEach(Array(vm.bundleIds.enumerated()), id: \.element.id) { index, item in
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
                                        Text(item.identifier ?? "")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(Color.dsMuted)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }

                                if index < vm.bundleIds.count - 1 {
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
        .alert("确认删除", isPresented: .init(
            get: { itemToDelete != nil },
            set: { if !$0 { itemToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let item = itemToDelete {
                    Task { try? await vm.deleteBundleId(id: item.id) }
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}
