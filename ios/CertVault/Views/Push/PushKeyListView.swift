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
                    title: "暂无推送密钥",
                    message: "导入 APNs .p8 密钥以发送推送通知",
                    actionTitle: "导入密钥"
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
                                    Task { await downloadService.download(endpoint: "/push-keys/\(key.id)/download") }
                                } label: {
                                    Label { Text("下载 P8") } icon: { HIcon(AppIcon.download) }
                                }
                                Button { keyToEdit = key } label: {
                                    Label { Text("编辑") } icon: { HIcon(AppIcon.edit) }
                                }
                                Button(role: .destructive) {
                                    keyToDelete = key
                                } label: {
                                    Label { Text("删除") } icon: { HIcon(AppIcon.delete) }
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
        .navigationTitle("推送密钥")
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
        .alert("确认删除", isPresented: .init(
            get: { keyToDelete != nil },
            set: { if !$0 { keyToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let key = keyToDelete {
                    Task { try? await vm.deleteKey(id: key.id) }
                }
            }
            Button("取消", role: .cancel) {}
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
                Section("选择 P8 文件") {
                    Button { showFilePicker = true } label: {
                        HStack {
                            HIcon(AppIcon.docUpload)
                                .foregroundStyle(Color.dsAccentBlue)
                            if let fname = selectedFileName {
                                Text(fname).font(.subheadline)
                            } else {
                                Text("点击选择 .p8 文件").foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Section("密钥信息") {
                    TextField("名称", text: $name)
                    TextField("Key ID", text: $keyId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Team ID", text: $teamId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Bundle IDs（逗号分隔，留空支持所有标识符）", text: $bundleIds)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("P8 内容") {
                    TextEditor(text: $p8Content)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("导入推送密钥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
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
                    if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                        p8Content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    let base = url.deletingPathExtension().lastPathComponent
                    if base.hasPrefix("AuthKey_") {
                        let extracted = String(base.dropFirst("AuthKey_".count))
                        if keyId.isEmpty { keyId = extracted }
                        if name.isEmpty { name = "APNs Key \(extracted)" }
                    }
                case .failure(let error):
                    errorMsg = error.localizedDescription
                }
            }
        }
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
                Section("密钥信息") {
                    TextField("名称", text: $name)
                    TextField("Key ID", text: $keyId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Team ID", text: $teamId)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Bundle IDs（逗号分隔，留空支持所有标识符）", text: $bundleIds)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("编辑推送密钥")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
    }
}
