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
                    Text(L10n.BundleID.identifier)
                } footer: {
                    Text(L10n.BundleID.identifierHint)
                }

                Section(NSLocalizedString("common.name", comment: "")) {
                    TextField("My App", text: $name)
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle(L10n.BundleID.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) {
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
