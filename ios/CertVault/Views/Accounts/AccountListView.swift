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
                DSEmptyState(
                    icon: AppIcon.lock,
                    title: L10n.Account.emptyTitle,
                    message: L10n.Account.emptyMessage,
                    actionTitle: L10n.Account.add
                ) { showCreateSheet = true }
            } else {
                ScrollView {
                    DSGroupedCard {
                        ForEach(vm.accounts) { account in
                            NavigationLink {
                                AccountDetailView(accountId: account.id)
                            } label: {
                                AccountRow(account: account)
                            }
                            .buttonStyle(.dsPressed)
                            .contextMenu {
                                Button(role: .destructive) {
                                    accountToDelete = account
                                } label: {
                                    Label { Text(L10n.delete) } icon: { HIcon(AppIcon.delete) }
                                }
                            }

                            if account.id != vm.accounts.last?.id {
                                DSDivider(leadingPadding: 56)
                            }
                        }
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.top, DS.spacingMD)
                }
                .pageBackground()
                .refreshable { await vm.loadAccounts() }
            }
        }
        .navigationTitle(L10n.Account.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showCreateSheet = true } label: {
                        Label { Text(L10n.Account.manualAdd) } icon: { HIcon(AppIcon.add) }
                    }
                    Button { showImportSheet = true } label: {
                        Label { Text(L10n.Account.quickImport) } icon: { HIcon(AppIcon.download) }
                    }
                    Button { showFileImporter = true } label: {
                        Label { Text(L10n.Account.uploadP8) } icon: { HIcon(AppIcon.docUpload) }
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
        .alert(L10n.Account.deleteTitle, isPresented: .init(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button(L10n.delete, role: .destructive) {
                if let acc = accountToDelete {
                    Task { try? await vm.delete(id: acc.id) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Account.deleteMessage)
        }
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: Account

    var body: some View {
        DSRow(
            icon: AppIcon.account,
            iconColor: .dsBlue,
            title: account.displayName,
            subtitle: "Key: \(account.key_id ?? "N/A")",
            trailing: account.remote_synced == true ? AnyView(DSBadge(text: L10n.Account.synced, color: .dsGreen)) : nil
        )
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
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        DSSectionHeader(L10n.Account.formP8Content)
                        DSInputFieldBuilder(icon: AppIcon.docUpload, focused: false) {
                            TextEditor(text: $p8Content)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.dsText)
                                .frame(minHeight: 120)
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        DSSectionHeader(L10n.Account.formSectionBasic)
                        DSInputField(icon: AppIcon.user, placeholder: L10n.Account.formName, text: $name)
                        DSInputFieldBuilder(icon: AppIcon.link, focused: false) {
                            TextField("", text: $issuerID, prompt: Text(L10n.Account.formIssuerId).foregroundColor(.dsTextTertiary))
                                .foregroundStyle(Color.dsText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        DSInputFieldBuilder(icon: AppIcon.lock, focused: false) {
                            TextField("", text: $keyID, prompt: Text(L10n.Account.formKeyId).foregroundColor(.dsTextTertiary))
                                .foregroundStyle(Color.dsText)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }
                    .cardStyle()

                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsDanger)
                    }

                    DSPrimaryButton(title: L10n.import, isLoading: isLoading, isDisabled: !isValid) {
                        doImport()
                    }
                }
                .padding(DS.spacingLG)
            }
            .background(Color.dsBackground)
            .navigationTitle(L10n.Account.importTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.import) { doImport() }
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
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        DSSectionHeader(L10n.Account.selectP8)
                        Button { showFilePicker = true } label: {
                            DSRow(
                                icon: AppIcon.docUpload,
                                iconColor: .dsBlue,
                                title: selectedFileName ?? L10n.Account.selectP8,
                                subtitle: nil,
                                showChevron: false
                            )
                        }
                        .buttonStyle(.dsPressed)
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        DSSectionHeader(L10n.Account.formSectionBasic)
                        DSInputField(icon: AppIcon.user, placeholder: L10n.Account.formName, text: $name)
                        DSInputFieldBuilder(icon: AppIcon.link, focused: false) {
                            TextField("", text: $issuerID, prompt: Text(L10n.Account.formIssuerId).foregroundColor(.dsTextTertiary))
                                .foregroundStyle(Color.dsText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        DSInputFieldBuilder(icon: AppIcon.lock, focused: false) {
                            TextField("", text: $keyID, prompt: Text(L10n.Account.formKeyId).foregroundColor(.dsTextTertiary))
                                .foregroundStyle(Color.dsText)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }
                    .cardStyle()

                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsDanger)
                    }

                    DSPrimaryButton(title: L10n.upload, isLoading: isLoading, isDisabled: !isValid) {
                        doUpload()
                    }
                }
                .padding(DS.spacingLG)
            }
            .background(Color.dsBackground)
            .navigationTitle(L10n.Account.uploadTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.upload) { doUpload() }
                        .disabled(!isValid || isLoading)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(contentTypes: [.data, .plainText, .item]) { url in
                    guard url.pathExtension.lowercased() == "p8" else {
                        errorMsg = "请选择 .p8 格式的文件"
                        return
                    }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        selectedFileData = try Data(contentsOf: url)
                        selectedFileName = url.lastPathComponent
                        if keyID.isEmpty, let fname = selectedFileName {
                            let base = fname.replacingOccurrences(of: ".p8", with: "")
                            if base.hasPrefix("AuthKey_") {
                                keyID = String(base.dropFirst("AuthKey_".count))
                            }
                        }
                    } catch {
                        errorMsg = "无法读取文件：\(error.localizedDescription)"
                    }
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

// MARK: - Document Picker (UIKit)

struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
