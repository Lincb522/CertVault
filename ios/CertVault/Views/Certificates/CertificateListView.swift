import SwiftUI
import HiconIcons

struct CertificateListView: View {
    @StateObject private var vm = CertificateViewModel()
    @State private var showCreate = false
    @State private var showSelfSign = false
    @State private var certToDelete: Certificate?
    @State private var searchText = ""
    @State private var filterType = "ALL"
    @ObservedObject private var downloadService = FileDownloadService.shared

    var filteredCerts: [Certificate] {
        var result = vm.certificates
        if filterType != "ALL" {
            result = result.filter { $0.type == filterType }
        }
        if !searchText.isEmpty {
            result = result.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.type ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                EmptyStateView(
                    icon: AppIcon.account,
                    title: "暂无开发者账号",
                    message: "请先在「账号」页面添加 Apple Developer API Key"
                )
            } else if vm.certificates.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                EmptyStateView(
                    icon: AppIcon.certificate,
                    title: "暂无证书",
                    message: "创建签名证书开始使用",
                    actionTitle: "创建证书"
                ) { showCreate = true }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if vm.accounts.count > 1 {
                            accountPicker
                                .padding(.horizontal, 16)
                        }

                        if !vm.quotas.isEmpty {
                            quotaSection
                                .padding(.horizontal, 16)
                        }

                        filterSection
                            .padding(.horizontal, 16)

                        certList
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .pageBackground()
                .searchable(text: $searchText, prompt: "搜索证书")
                .refreshable {
                    await vm.loadCertificates()
                    await vm.loadQuota()
                }
            }
        }
        .navigationTitle("证书管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showCreate = true } label: {
                        Label { Text("创建证书") } icon: { HIcon(AppIcon.addCircle) }
                    }
                    Button { showSelfSign = true } label: {
                        Label { Text("自签证书") } icon: { HIcon(AppIcon.pen) }
                    }
                } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.certificates.isEmpty {
                LoadingView()
            }
        }
        .task {
            AppLogger.ui.info("🖼️ CertificateListView appeared")
            await vm.loadAccounts()
            await vm.loadQuota()
        }
        .sheet(isPresented: $showCreate) { CreateCertView(vm: vm) }
        .sheet(isPresented: $showSelfSign) { SelfSignView(vm: vm) }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert("确认删除", isPresented: .init(
            get: { certToDelete != nil },
            set: { if !$0 { certToDelete = nil } }
        )) {
            Button("删除并撤销", role: .destructive) {
                if let cert = certToDelete {
                    Task { try? await vm.delete(id: cert.id) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("该证书将从 Apple 撤销并从本地删除")
        }
    }

    // MARK: - Components

    private var accountPicker: some View {
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
                Task {
                    await vm.loadCertificates()
                    await vm.loadQuota()
                }
            }
        }
        .padding(14)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    private var quotaSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(vm.quotas.keys.sorted()), id: \.self) { key in
                if let quota = vm.quotas[key] {
                    HStack {
                        Text(quota.label ?? key)
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                        Spacer()
                        Text("\(quota.used)/\(quota.limit)")
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(quota.available > 0 ? Color.dsAccent : Color.dsAccentPink)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "全部", isSelected: filterType == "ALL") {
                    filterType = "ALL"
                }
                ForEach(vm.certTypes) { type in
                    FilterChip(title: type.label, isSelected: filterType == type.value) {
                        filterType = type.value
                    }
                }
            }
        }
    }

    private var certList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredCerts.enumerated()), id: \.element.id) { index, cert in
                NavigationLink {
                    CertificateDetailView(certId: cert.id, accountId: vm.selectedAccountId)
                } label: {
                    CertRow(cert: cert)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        let endpoint = cert.canDownloadP12
                            ? "/certificates/\(cert.id)/download"
                            : "/certificates/\(cert.id)/download-cer"
                        Task { await downloadService.download(endpoint: endpoint) }
                    } label: {
                        Label { Text("下载") } icon: { HIcon(AppIcon.download) }
                    }
                    Button(role: .destructive) {
                        certToDelete = cert
                    } label: {
                        Label { Text("删除") } icon: { HIcon(AppIcon.delete) }
                    }
                }

                if index < filteredCerts.count - 1 {
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
    }
}

// MARK: - Certificate Row

private struct CertRow: View {
    let cert: Certificate

    var body: some View {
        HStack(spacing: 14) {
            HIcon(AppIcon.certificate)
                .font(.body)
                .foregroundStyle(cert.isExpired ? Color.dsAccentPink : Color.dsAccentPurple)
                .frame(width: 40, height: 40)
                .background(
                    (cert.isExpired ? Color.dsAccentPink : Color.dsAccentPurple).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(cert.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(cert.type ?? "")
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                    if cert.canDownloadP12 {
                        StatusBadge("P12", color: .dsAccentBlue)
                    } else {
                        StatusBadge("CER", color: .dsAccentOrange)
                    }
                }
            }

            Spacer()

            if cert.isExpired {
                StatusBadge("已过期", color: .dsAccentPink)
            }

            HIcon(AppIcon.chevronRight)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dsMuted.opacity(0.4))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? .white : Color.dsMuted)
                .background(
                    isSelected ? AnyShapeStyle(Color.dsAccentBlue) : AnyShapeStyle(Color.dsSurface),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.dsBorder, lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
