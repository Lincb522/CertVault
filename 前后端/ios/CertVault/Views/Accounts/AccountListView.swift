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
                    title: L10n.Account.emptyTitle,
                    message: L10n.Account.emptyMessage,
                    actionTitle: L10n.Account.add
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
                                    Label { Text(L10n.delete) } icon: { HIcon(AppIcon.delete) }
                                }
                            }

                            if index < vm.accounts.count - 1 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .glassCard(cornerRadius: 14)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
        .glassSheet(isPresented: $showCreateSheet) {
            AccountFormView(vm: vm, mode: .create)
        }
        .glassSheet(isPresented: $showImportSheet) {
            ImportP8Sheet(vm: vm)
        }
        .glassSheet(isPresented: $showFileImporter) {
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
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Key: \(account.key_id ?? "N/A")")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(1)
                    if account.remote_synced == true {
                        StatusBadge(L10n.Account.synced, color: .dsAccent)
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
                Section(L10n.Account.formP8Content) {
                    TextEditor(text: $p8Content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                }

                Section(L10n.Account.formSectionBasic) {
                    TextField(L10n.Account.formName, text: $name)
                    TextField(L10n.Account.formIssuerId, text: $issuerID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(L10n.Account.formKeyId, text: $keyID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.Account.importTitle)
            .sheetNavStyle()
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
        .sheetStyle()
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
                Section(L10n.Account.selectP8) {
                    Button { showFilePicker = true } label: {
                        HStack {
                            HIcon(AppIcon.docUpload)
                                .foregroundStyle(Color.dsAccentBlue)
                            if let name = selectedFileName {
                                Text(name).font(.subheadline)
                            } else {
                                Text(L10n.Account.selectP8).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Section(L10n.Account.formSectionBasic) {
                    TextField(L10n.Account.formName, text: $name)
                    TextField(L10n.Account.formIssuerId, text: $issuerID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(L10n.Account.formKeyId, text: $keyID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.Account.uploadTitle)
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.upload) { doUpload() }
                        .disabled(!isValid || isLoading)
                }
            }
            .glassSheet(isPresented: $showFilePicker) {
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
        .sheetStyle()
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
