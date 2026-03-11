import SwiftUI
import HiconIcons

struct CreateCertView: View {
    @ObservedObject var vm: CertificateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType = "IOS_DEVELOPMENT"
    @State private var name = ""
    @State private var password = "123456"
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var showRevokeConfirm = false
    @State private var conflictMessage = ""

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
                    Picker(L10n.Cert.type, selection: $selectedType) {
                        ForEach(vm.certTypes) { type in
                            VStack(alignment: .leading) {
                                Text(type.label)
                            }
                            .tag(type.value)
                        }
                    }
                } header: {
                    Text(L10n.Cert.type)
                } footer: {
                    if let type = vm.certTypes.first(where: { $0.value == selectedType }) {
                        Text(type.desc ?? "")
                    }
                }

                Section(NSLocalizedString("cert.form.section", comment: "")) {
                    TextField(NSLocalizedString("cert.form.name", comment: ""), text: $name)
                    HStack {
                        Text(L10n.Cert.password)
                        Spacer()
                        TextField(L10n.Register.password, text: $password)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                if let quota = vm.quotas[selectedType] {
                    Section(L10n.Cert.quotaTitle) {
                        HStack {
                            Text(L10n.Cert.quotaUsed)
                            Spacer()
                            Text("\(quota.used) / \(quota.limit)")
                                .foregroundStyle(quota.available > 0 ? .green : .red)
                        }
                        if quota.available <= 0 {
                            HStack {
                                HIcon(AppIcon.warning)
                                    .foregroundStyle(.orange)
                                Text(L10n.Cert.quotaFull)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .scrollContentBackground(.hidden)
            .pageBackground()
            .navigationTitle(L10n.Cert.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) { create(revokeAndRecreate: false) }
                        .disabled(isLoading)
                }
            }
            .alert(L10n.Cert.quotaTitle, isPresented: $showRevokeConfirm) {
                Button(NSLocalizedString("cert.revokeAndRecreate", comment: ""), role: .destructive) {
                    create(revokeAndRecreate: true)
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(conflictMessage)
            }
        }
        .sheetStyle()
    }

    private func create(revokeAndRecreate: Bool) {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                _ = try await vm.create(
                    type: selectedType,
                    name: name.isEmpty ? nil : name,
                    password: password,
                    revokeAndRecreate: revokeAndRecreate
                )
                dismiss()
            } catch let error as APIError {
                if case .conflict(let msg, _) = error {
                    conflictMessage = msg
                    showRevokeConfirm = true
                } else {
                    errorMsg = error.localizedDescription
                }
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
