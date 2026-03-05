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
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.spacing2XL) {
                    if vm.accounts.count > 1 {
                        accountSection
                    }

                    typeSection
                    formSection

                    if let quota = vm.quotas[selectedType] {
                        quotaSection(quota)
                    }

                    if let err = errorMsg {
                        errorSection(err)
                    }

                    createButton
                }
                .padding(.horizontal, DS.spacingLG)
                .padding(.top, DS.spacingMD)
                .padding(.bottom, DS.spacing3XL)
            }
            .pageBackground()
            .navigationTitle(L10n.Cert.create)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundStyle(Color.dsBrand)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) { create(revokeAndRecreate: false) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.dsBrand)
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
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.account)

            DSGroupedCard {
                HStack {
                    HIcon(AppIcon.account)
                        .font(.callout)
                        .foregroundStyle(Color.dsBrand)
                        .frame(width: 20)

                    Picker(L10n.select, selection: $vm.selectedAccountId) {
                        ForEach(vm.accounts) { acc in
                            Text(acc.displayName).tag(acc.id)
                        }
                    }
                    .tint(Color.dsBrand)
                }
                .padding(.vertical, DS.spacingMD)
                .padding(.horizontal, DS.spacingLG)
            }
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Cert.type)

            DSGroupedCard {
                VStack(spacing: 0) {
                    HStack {
                        HIcon(AppIcon.certificate)
                            .font(.callout)
                            .foregroundStyle(Color.dsBrand)
                            .frame(width: 20)

                        Picker(L10n.Cert.type, selection: $selectedType) {
                            ForEach(vm.certTypes) { type in
                                Text(type.label).tag(type.value)
                            }
                        }
                        .tint(Color.dsBrand)
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)

                    if let type = vm.certTypes.first(where: { $0.value == selectedType }),
                       let desc = type.desc, !desc.isEmpty {
                        DSDivider(leadingPadding: DS.spacingLG + 20 + DS.spacingMD)

                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DS.spacingLG)
                            .padding(.vertical, DS.spacingMD)
                    }
                }
            }
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("cert.form.section", comment: ""))

            DSGroupedCard {
                VStack(spacing: 0) {
                    DSInputField(
                        icon: AppIcon.pen,
                        placeholder: NSLocalizedString("cert.form.name", comment: ""),
                        text: $name
                    )
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.vertical, DS.spacingMD)

                    DSDivider(leadingPadding: DS.spacingLG + 20 + DS.spacingMD)

                    DSInputField(
                        icon: AppIcon.lock,
                        placeholder: L10n.Register.password,
                        text: $password,
                        isSecure: true
                    )
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.vertical, DS.spacingMD)
                }
            }
        }
    }

    // MARK: - Quota Section

    private func quotaSection(_ quota: CertQuota) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(L10n.Cert.quotaTitle)

            DSGroupedCard {
                VStack(spacing: 0) {
                    HStack {
                        Text(L10n.Cert.quotaUsed)
                            .font(.subheadline)
                            .foregroundStyle(Color.dsText)
                        Spacer()
                        Text("\(quota.used) / \(quota.limit)")
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(quota.available > 0 ? Color.dsSuccess : Color.dsDanger)
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)

                    if quota.available <= 0 {
                        DSDivider(leadingPadding: DS.spacingLG)

                        HStack(spacing: DS.spacingSM) {
                            HIcon(AppIcon.warning)
                                .font(.caption)
                                .foregroundStyle(Color.dsWarning)
                            Text(L10n.Cert.quotaFull)
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.spacingLG)
                        .padding(.vertical, DS.spacingMD)
                    }
                }
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: DS.spacingSM) {
            HIcon(AppIcon.warning)
                .font(.caption)
                .foregroundStyle(Color.dsDanger)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.dsDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.spacingLG)
    }

    private var createButton: some View {
        DSPrimaryButton(
            title: L10n.create,
            isLoading: isLoading,
            isDisabled: false
        ) {
            create(revokeAndRecreate: false)
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
