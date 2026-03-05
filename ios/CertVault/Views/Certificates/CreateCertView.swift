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
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    if vm.accounts.count > 1 {
                        DSGroupedCard {
                            VStack(alignment: .leading, spacing: DS.spacingMD) {
                                DSSectionHeader(L10n.account)
                                Picker(L10n.select, selection: $vm.selectedAccountId) {
                                    ForEach(vm.accounts) { acc in
                                        Text(acc.displayName).tag(acc.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.dsBrand)
                            }
                            .padding(DS.spacingLG)
                        }
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(L10n.Cert.type)
                            Picker(L10n.Cert.type, selection: $selectedType) {
                                ForEach(vm.certTypes) { type in
                                    Text(type.label).tag(type.value)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.dsBrand)

                            if let type = vm.certTypes.first(where: { $0.value == selectedType }) {
                                if let desc = type.desc {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(Color.dsTextSecondary)
                                }
                            }
                        }
                        .padding(DS.spacingLG)
                    }

                    DSGroupedCard {
                        VStack(alignment: .leading, spacing: DS.spacingMD) {
                            DSSectionHeader(NSLocalizedString("cert.form.section", comment: ""))
                            DSInputField(icon: AppIcon.certificate, placeholder: NSLocalizedString("cert.form.name", comment: ""), text: $name)
                            DSInputField(icon: AppIcon.lock, placeholder: L10n.Cert.password, text: $password)
                        }
                        .padding(DS.spacingLG)
                    }

                    if let quota = vm.quotas[selectedType] {
                        DSGroupedCard {
                            VStack(alignment: .leading, spacing: DS.spacingMD) {
                                DSSectionHeader(L10n.Cert.quotaTitle)
                                HStack {
                                    Text(L10n.Cert.quotaUsed)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsText)
                                    Spacer()
                                    Text("\(quota.used) / \(quota.limit)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(quota.available > 0 ? Color.dsSuccess : Color.dsDanger)
                                }
                                if quota.available <= 0 {
                                    HStack(spacing: DS.spacingSM) {
                                        HIcon(AppIcon.warning)
                                            .foregroundStyle(Color.dsWarning)
                                        Text(L10n.Cert.quotaFull)
                                            .font(.caption)
                                            .foregroundStyle(Color.dsTextSecondary)
                                    }
                                }
                            }
                            .padding(DS.spacingLG)
                        }
                    }

                    if let err = errorMsg {
                        Text(err)
                            .foregroundStyle(Color.dsDanger)
                            .font(.caption)
                    }

                    DSPrimaryButton(title: L10n.create, isLoading: isLoading) {
                        create(revokeAndRecreate: false)
                    }
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(L10n.Cert.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
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
