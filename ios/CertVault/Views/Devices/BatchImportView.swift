import SwiftUI

struct BatchImportView: View {
    @ObservedObject var vm: DeviceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            Form {
                if vm.accounts.count > 1 {
                    Section("账号") {
                        Picker("选择账号", selection: $vm.selectedAccountId) {
                            ForEach(vm.accounts) { acc in
                                Text(acc.displayName).tag(acc.id)
                            }
                        }
                    }
                }

                Section {
                    TextEditor(text: $text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                } header: {
                    Text("设备列表")
                } footer: {
                    Text("每行一个设备，格式：UDID,设备名称\n例如：\n00008030-001A1234567890,iPhone 15 Pro\n00008030-001B5678901234,iPad Air")
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("批量导入设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") { doImport() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .alert("导入成功", isPresented: $success) {
                Button("好") { dismiss() }
            } message: {
                Text("设备已批量注册")
            }
        }
    }

    private func doImport() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                try await vm.batchRegister(text: text)
                success = true
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
