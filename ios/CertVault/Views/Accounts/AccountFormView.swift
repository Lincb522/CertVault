import SwiftUI
import HiconIcons

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
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.Account.formSectionBasic)
                            DSInputField(icon: AppIcon.edit, placeholder: L10n.Account.formName, text: $name)
                            DSInputField(icon: AppIcon.user, placeholder: "Issuer ID", text: $issuerID)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            DSInputField(icon: AppIcon.lock, placeholder: "Key ID", text: $keyID)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                        .padding(DS.spacingLG)
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.Account.formP8Content)
                            TextEditor(text: $privateKey)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.dsText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(DS.spacingMD)
                                .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.radiusMD)
                                        .stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5)
                                )
                            Text(L10n.Account.formP8Hint)
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        .padding(DS.spacingLG)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .foregroundStyle(Color.dsDanger)
                            .font(.caption)
                    }

                    DSPrimaryButton(
                        title: isEdit ? L10n.save : L10n.create,
                        isLoading: isLoading,
                        isDisabled: !isValid
                    ) {
                        save()
                    }
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(isEdit ? L10n.Account.edit : L10n.Account.add)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
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
