import SwiftUI
import HiconIcons
import UniformTypeIdentifiers

struct PushKeyListView: View {
    @StateObject private var vm = PushViewModel()
    @State private var showCreate = false
    @State private var keyToDelete: PushKey?
    @State private var keyToEdit: PushKey?
    @ObservedObject private var downloadService = FileDownloadService.shared

    var body: some View {
        Group {
            if vm.pushKeys.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: AppIcon.pushKey,
                    title: L10n.Push.keysEmptyTitle,
                    message: L10n.Push.keysEmptyMessage,
                    actionTitle: NSLocalizedString("push.keys.importAction", comment: "")
                ) { showCreate = true }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vm.pushKeys.enumerated()), id: \.element.id) { index, key in
                            Button { keyToEdit = key } label: {
                                PushKeyRow(key: key)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await downloadService.download(endpoint: "/push/keys/\(key.id)/download") }
                                } label: {
                                    Label { Text(L10n.Push.keysDownloadP8) } icon: { HIcon(AppIcon.download) }
                                }
                                Button { keyToEdit = key } label: {
                                    Label { Text(L10n.edit) } icon: { HIcon(AppIcon.edit) }
                                }
                                Button(role: .destructive) {
                                    keyToDelete = key
                                } label: {
                                    Label { Text(L10n.delete) } icon: { HIcon(AppIcon.delete) }
                                }
                            }

                            if index < vm.pushKeys.count - 1 {
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
                .refreshable { await vm.loadKeys() }
            }
        }
        .navigationTitle(L10n.Push.keysTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    HIcon(AppIcon.addCircle)
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.pushKeys.isEmpty {
                LoadingView()
            }
        }
        .task { await vm.loadKeys() }
        .sheet(isPresented: $showCreate) {
            CreatePushKeySheet(vm: vm)
        }
        .sheet(item: $keyToEdit) { key in
            EditPushKeySheet(vm: vm, key: key)
        }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert(L10n.Push.keysDeleteTitle, isPresented: .init(
            get: { keyToDelete != nil },
            set: { if !$0 { keyToDelete = nil } }
        )) {
            Button(L10n.delete, role: .destructive) {
                if let key = keyToDelete {
                    Task { try? await vm.deleteKey(id: key.id) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }
}

// MARK: - Push Key Row

private struct PushKeyRow: View {
    let key: PushKey

    var body: some View {
        HStack(spacing: 14) {
            HIcon(AppIcon.pushKey)
                .font(.body)
                .foregroundStyle(Color.dsAccentPink)
                .frame(width: 40, height: 40)
                .background(Color.dsAccentPink.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(key.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                HStack(spacing: 8) {
                    if let kid = key.key_id {
                        Text("Key: \(kid)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.dsMuted)
                    }
                    if let tid = key.team_id {
                        Text("Team: \(tid)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.dsMuted)
                    }
                }
                if let bundles = key.bundle_ids, !bundles.isEmpty {
                    Text(bundles)
                        .font(.caption2)
                        .foregroundStyle(Color.dsMuted.opacity(0.6))
                        .lineLimit(1)
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

// MARK: - Create Sheet

private struct CreatePushKeySheet: View {
    @ObservedObject var vm: PushViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var keyId = ""
    @State private var teamId = ""
    @State private var bundleIds = ""
    @State private var p8Content = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showFilePicker = false
    @State private var selectedFileName: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.Account.selectP8) {
                    Button { showFilePicker = true } label: {
                        HStack {
                            HIcon(AppIcon.docUpload)
                                .foregroundStyle(Color.dsAccentBlue)
                            if let fname = selectedFileName {
                                Text(fname).font(.subheadline)
                            } else {
                                Text(L10n.Push.keysSelectP8).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Section(NSLocalizedString("push.keys.section.info", comment: "")) {
                    TextField(NSLocalizedString("push.keys.field.name", comment: ""), text: $name)
                    TextField("Key ID", text: $keyId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Team ID", text: $teamId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(NSLocalizedString("push.keys.field.bundleIds", comment: ""), text: $bundleIds)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section(NSLocalizedString("push.keys.section.p8", comment: "")) {
                    TextEditor(text: $p8Content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.Push.keysImport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.import) {
                        isLoading = true
                        Task {
                            do {
                                try await vm.createKey(name: name, keyId: keyId, teamId: teamId,
                                                       bundleIds: bundleIds, p8Content: p8Content)
                                dismiss()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(contentTypes: [.data, .plainText, .item]) { url in
                    guard url.pathExtension.lowercased() == "p8" else {
                        errorMsg = "请选择 .p8 格式的文件"
                        return
                    }
                    selectedFileName = url.lastPathComponent
                    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                        p8Content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    let base = url.deletingPathExtension().lastPathComponent
                    if base.hasPrefix("AuthKey_") {
                        let extracted = String(base.dropFirst("AuthKey_".count))
                        if keyId.isEmpty { keyId = extracted }
                        if name.isEmpty { name = "APNs Key \(extracted)" }
                    }
                }
            }
        }
        .sheetStyle()
    }

    private var isValid: Bool {
        !name.isEmpty && !keyId.isEmpty && !teamId.isEmpty && !p8Content.isEmpty
    }
}

// MARK: - Edit Sheet

private struct EditPushKeySheet: View {
    @ObservedObject var vm: PushViewModel
    let key: PushKey
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var keyId = ""
    @State private var teamId = ""
    @State private var bundleIds = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("push.keys.section.info", comment: "")) {
                    TextField(NSLocalizedString("push.keys.field.name", comment: ""), text: $name)
                    TextField("Key ID", text: $keyId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Team ID", text: $teamId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(NSLocalizedString("push.keys.field.bundleIds", comment: ""), text: $bundleIds)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.Push.keysEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        isLoading = true
                        errorMsg = nil
                        Task {
                            do {
                                try await vm.updateKey(id: key.id, name: name, keyId: keyId,
                                                       teamId: teamId, bundleIds: bundleIds)
                                dismiss()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .onAppear {
                name = key.name ?? ""
                keyId = key.key_id ?? ""
                teamId = key.team_id ?? ""
                bundleIds = key.bundle_ids ?? ""
            }
        }
        .sheetStyle()
    }
}
