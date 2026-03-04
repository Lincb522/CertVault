import SwiftUI
import HiconIcons
import UniformTypeIdentifiers

struct AccountListView: View {
    @StateObject private var vm = AccountViewModel()
    @State private var showCreateSheet = false
    @State private var showImportSheet = false
    @State private var showFileImporter = false
    @State private var accountToDelete: Account?

    var body: some View {
        Group {
            if vm.accounts.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: AppIcon.lock,
                    title: "暂无账号",
                    message: "添加 Apple Developer API Key 开始管理证书和描述文件",
                    actionTitle: "添加账号"
                ) { showCreateSheet = true }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.accounts.enumerated()), id: \.element.id) { index, account in
                            NavigationLink {
                                AccountDetailView(accountId: account.id)
                            } label: {
                                AccountRow(account: account)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    accountToDelete = account
                                } label: {
                                    Label { Text("删除") } icon: { HIcon(AppIcon.delete) }
                                }
                            }

                            if index < vm.accounts.count - 1 {
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
                    .padding(.top, 8)
                }
                .pageBackground()
                .refreshable { await vm.loadAccounts() }
            }
        }
        .navigationTitle("开发者账号")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showCreateSheet = true } label: {
                        Label { Text("手动添加") } icon: { HIcon(AppIcon.add) }
                    }
                    Button { showImportSheet = true } label: {
                        Label { Text("快速导入 P8") } icon: { HIcon(AppIcon.download) }
                    }
                    Button { showFileImporter = true } label: {
                        Label { Text("上传 P8 文件") } icon: { HIcon(AppIcon.docUpload) }
                    }
                } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.accounts.isEmpty {
                LoadingView()
            }
        }
        .task {
            AppLogger.ui.info("🖼️ AccountListView appeared")
            await vm.loadAccounts()
        }
        .sheet(isPresented: $showCreateSheet) {
            AccountFormView(vm: vm, mode: .create)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportP8Sheet(vm: vm)
        }
        .sheet(isPresented: $showFileImporter) {
            UploadP8Sheet(vm: vm)
        }
        .alert("确认删除", isPresented: .init(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let acc = accountToDelete {
                    Task { try? await vm.delete(id: acc.id) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，该账号关联的所有本地数据将被清除")
        }
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 14) {
            HIcon(AppIcon.account)
                .font(.title3)
                .foregroundStyle(Color.dsAccentBlue)
                .frame(width: 40, height: 40)
                .background(Color.dsAccentBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dsText)
                HStack(spacing: 6) {
                    Text("Key: \(account.key_id ?? "N/A")")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.dsMuted)
                    if account.remote_synced == true {
                        StatusBadge("已同步", color: .dsAccent)
                    }
                }
            }

            Spacer()

            HIcon(AppIcon.chevronRight)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.dsMuted.opacity(0.4))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Import P8 Sheet

private struct ImportP8Sheet: View {
    @ObservedObject var vm: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var p8Content = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("P8 密钥内容") {
                    TextEditor(text: $p8Content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                }

                Section("账号信息") {
                    TextField("账号名称", text: $name)
                    TextField("Issuer ID", text: $issuerID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Key ID", text: $keyID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("快速导入 P8")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") { doImport() }
                        .disabled(!isValid || isLoading)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !issuerID.isEmpty && !keyID.isEmpty && !p8Content.isEmpty
    }

    private func doImport() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await vm.importP8(name: name, issuerID: issuerID, keyID: keyID, privateKey: p8Content)
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Upload P8 Sheet

private struct UploadP8Sheet: View {
    @ObservedObject var vm: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?
    @State private var name = ""
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("选择 P8 文件") {
                    Button { showFilePicker = true } label: {
                        HStack {
                            HIcon(AppIcon.docUpload)
                                .foregroundStyle(Color.dsAccentBlue)
                            if let name = selectedFileName {
                                Text(name).font(.subheadline)
                            } else {
                                Text("点击选择 .p8 文件").foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Section("账号信息") {
                    TextField("账号名称", text: $name)
                    TextField("Issuer ID", text: $issuerID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Key ID", text: $keyID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("上传 P8 文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("上传") { doUpload() }
                        .disabled(!isValid || isLoading)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "p8") ?? .data,
                    .plainText,
                    .data
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    selectedFileName = url.lastPathComponent
                    selectedFileData = try? Data(contentsOf: url)
                    if keyID.isEmpty, let fname = selectedFileName {
                        let base = fname.replacingOccurrences(of: ".p8", with: "")
                        if base.hasPrefix("AuthKey_") {
                            keyID = String(base.dropFirst("AuthKey_".count))
                        }
                    }
                case .failure(let error):
                    errorMsg = error.localizedDescription
                }
            }
        }
    }

    private var isValid: Bool {
        selectedFileData != nil && !name.isEmpty && !issuerID.isEmpty && !keyID.isEmpty
    }

    private func doUpload() {
        guard let data = selectedFileData else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await vm.importP8(
                    name: name, issuerID: issuerID, keyID: keyID,
                    privateKey: String(data: data, encoding: .utf8) ?? ""
                )
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
