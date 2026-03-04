import SwiftUI

struct CreateBundleIDView: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var identifier = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("com.example.myapp", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Bundle Identifier")
                } footer: {
                    Text("应用的唯一标识符，如 com.yourcompany.appname")
                }

                Section("名称") {
                    TextField("My App", text: $name)
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("创建 Bundle ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        isLoading = true
                        errorMsg = nil
                        Task {
                            do {
                                try await vm.createBundleId(identifier: identifier, name: name)
                                dismiss()
                            } catch {
                                errorMsg = error.localizedDescription
                            }
                            isLoading = false
                        }
                    }
                    .disabled(identifier.isEmpty || name.isEmpty || isLoading)
                }
            }
        }
    }
}
