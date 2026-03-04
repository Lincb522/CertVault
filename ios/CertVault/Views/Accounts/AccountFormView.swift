import SwiftUI

struct AccountFormView: View {
    @ObservedObject var vm: AccountViewModel
    let mode: Mode
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case create
        case edit(Account)
    }

    @State private var name = ""
    @State private var issuerID = ""
    @State private var keyID = ""
    @State private var privateKey = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("账号名称", text: $name)
                    TextField("Issuer ID", text: $issuerID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Key ID", text: $keyID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section {
                    TextEditor(text: $privateKey)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                } header: {
                    Text("P8 私钥内容")
                } footer: {
                    Text("粘贴 .p8 文件的完整内容，包含 BEGIN/END PRIVATE KEY")
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(isEdit ? "编辑账号" : "添加账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "保存" : "创建") { save() }
                        .disabled(!isValid || isLoading)
                }
            }
            .onAppear { prefill() }
        }
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.isEmpty && !issuerID.isEmpty && !keyID.isEmpty && (!isEdit ? !privateKey.isEmpty : true)
    }

    private func prefill() {
        if case .edit(let account) = mode {
            name = account.name ?? ""
            issuerID = account.issuer_id ?? ""
            keyID = account.key_id ?? ""
        }
    }

    private func save() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                if case .edit(let account) = mode {
                    try await vm.update(
                        id: account.id, name: name, issuerID: issuerID,
                        keyID: keyID, privateKey: privateKey.isEmpty ? nil : privateKey
                    )
                } else {
                    try await vm.create(name: name, issuerID: issuerID, keyID: keyID, privateKey: privateKey)
                }
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
