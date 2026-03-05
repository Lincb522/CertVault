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

    private var filterOptions: [String] {
        ["全部"] + vm.certTypes.map(\.label)
    }

    private var selectedFilterLabel: String {
        get {
            if filterType == "ALL" { return "全部" }
            return vm.certTypes.first { $0.value == filterType }?.label ?? "全部"
        }
        set {
            if newValue == "全部" {
                filterType = "ALL"
            } else {
                filterType = vm.certTypes.first { $0.label == newValue }?.value ?? "ALL"
            }
        }
    }

    var body: some View {
        Group {
            if !vm.isLoading && vm.accounts.isEmpty {
                DSEmptyState(
                    icon: AppIcon.account,
                    title: L10n.Cert.noAccountTitle,
                    message: L10n.Cert.noAccountMessage
                )
            } else if vm.certificates.isEmpty && !vm.isLoading && !vm.selectedAccountId.isEmpty {
                DSEmptyState(
                    icon: AppIcon.certificate,
                    title: L10n.Cert.emptyTitle,
                    message: L10n.Cert.emptyMessage,
                    actionTitle: L10n.Cert.create
                ) { showCreate = true }
            } else {
                ScrollView {
                    VStack(spacing: DS.spacingMD) {
                        if vm.accounts.count > 1 {
                            accountPicker
                                .padding(.horizontal, DS.spacingLG)
                        }

                        if !vm.quotas.isEmpty {
                            quotaSection
                                .padding(.horizontal, DS.spacingLG)
                        }

                        filterSection
                            .padding(.horizontal, DS.spacingLG)

                        certList
                            .padding(.horizontal, DS.spacingLG)
                    }
                    .padding(.top, DS.spacingSM)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .searchable(text: $searchText, prompt: L10n.Cert.search)
                .refreshable {
                    await vm.loadCertificates()
                    await vm.loadQuota()
                }
            }
        }
        .navigationTitle(L10n.Cert.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showCreate = true } label: {
                        Label { Text(L10n.Cert.create) } icon: { HIcon(AppIcon.addCircle) }
                    }
                    Button { showSelfSign = true } label: {
                        Label { Text(L10n.Cert.selfSign) } icon: { HIcon(AppIcon.pen) }
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
        .alert(L10n.Cert.deleteTitle, isPresented: .init(
            get: { certToDelete != nil },
            set: { if !$0 { certToDelete = nil } }
        )) {
            Button(L10n.delete, role: .destructive) {
                if let cert = certToDelete {
                    Task { try? await vm.delete(id: cert.id) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Cert.deleteMessage)
        }
    }

    // MARK: - Components

    private var accountPicker: some View {
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
                Task {
                    await vm.loadCertificates()
                    await vm.loadQuota()
                }
            }
        }
        .padding(DS.spacingLG)
        .cardStyle()
    }

    private var quotaSection: some View {
        DSGroupedCard {
            VStack(spacing: DS.spacingSM) {
                ForEach(Array(vm.quotas.keys.sorted()), id: \.self) { key in
                    if let quota = vm.quotas[key] {
                        HStack {
                            Text(quota.label ?? key)
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                            Spacer()
                            Text("\(quota.used)/\(quota.limit)")
                                .font(.dsMono)
                                .foregroundStyle(quota.available > 0 ? Color.dsBlue : Color.dsPink)
                        }
                        .padding(.vertical, DS.spacingSM)
                    }
                }
            }
            .padding(DS.spacingLG)
        }
    }

    private var filterSection: some View {
        DSChipGroup(
            options: filterOptions,
            selected: Binding(
                get: {
                    if filterType == "ALL" { return "全部" }
                    return vm.certTypes.first { $0.value == filterType }?.label ?? "全部"
                },
                set: { newValue in
                    if newValue == "全部" {
                        filterType = "ALL"
                    } else {
                        filterType = vm.certTypes.first { $0.label == newValue }?.value ?? "ALL"
                    }
                }
            )
        )
    }

    private var certList: some View {
        DSGroupedCard {
            LazyVStack(spacing: 0) {
                ForEach(filteredCerts) { cert in
                    NavigationLink {
                        CertificateDetailView(certId: cert.id, accountId: vm.selectedAccountId)
                    } label: {
                        CertRow(cert: cert)
                    }
                    .buttonStyle(.dsPressed)
                    .contextMenu {
                        Button {
                            let endpoint = cert.canDownloadP12
                                ? "/certificates/\(cert.id)/download"
                                : "/certificates/\(cert.id)/download-cer"
                            Task { await downloadService.download(endpoint: endpoint) }
                        } label: {
                            Label { Text(L10n.download) } icon: { HIcon(AppIcon.download) }
                        }
                        Button(role: .destructive) {
                            certToDelete = cert
                        } label: {
                            Label { Text(L10n.delete) } icon: { HIcon(AppIcon.delete) }
                        }
                    }

                    if cert.id != filteredCerts.last?.id {
                        DSDivider(leadingPadding: 68)
                    }
                }
            }
            .padding(.vertical, DS.spacingXS)
        }
    }
}

// MARK: - Certificate Row

private struct CertRow: View {
    let cert: Certificate

    var body: some View {
        DSRow(
            icon: AppIcon.certificate,
            iconColor: cert.isExpired ? Color.dsPink : Color.dsPurple,
            title: cert.displayName,
            subtitle: Localized.certType(cert.type ?? ""),
            trailing: AnyView(
                HStack(spacing: DS.spacingSM) {
                    DSBadge(
                        text: cert.canDownloadP12 ? "P12" : "CER",
                        color: cert.canDownloadP12 ? .dsBlue : .dsOrange
                    )
                    if cert.isExpired {
                        DSBadge(text: Localized.status("EXPIRED"), color: .dsPink)
                    }
                }
            ),
            showChevron: true
        )
    }
}
