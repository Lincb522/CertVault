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
                    Section(L10n.account) {
                        Picker(L10n.select, selection: $vm.selectedAccountId) {
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
                    Text(L10n.BatchImport.section)
                } footer: {
                    Text(L10n.BatchImport.hint)
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.BatchImport.title)
            .sheetNavStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.import) { doImport() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .alert(L10n.BatchImport.successTitle, isPresented: $success) {
                Button(L10n.ok) { dismiss() }
            } message: {
                Text(L10n.BatchImport.successMessage)
            }
        }
        .sheetStyle()
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
