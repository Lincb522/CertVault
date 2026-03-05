import SwiftUI
import HiconIcons

struct SelfSignView: View {
    @ObservedObject var vm: CertificateViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode = 0
    @State private var name = ""
    @State private var password = "123456"
    @State private var commonName = ""
    @State private var email = ""
    @State private var organization = ""
    @State private var country = "CN"
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var success = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spacingLG) {
                    Picker("", selection: $mode) {
                        Text(L10n.Cert.selfSign).tag(0)
                        Text(L10n.Cert.generateCA).tag(1)
                    }
                    .pickerStyle(.segmented)

                    if mode == 0 {
                        selfSignForm
                    } else {
                        caForm
                    }

                    if let err = errorMsg {
                        Text(err)
                            .foregroundStyle(Color.dsDanger)
                            .font(.caption)
                    }

                    DSPrimaryButton(
                        title: mode == 0
                            ? NSLocalizedString("cert.selfSign.generate", comment: "")
                            : NSLocalizedString("cert.ca.create", comment: ""),
                        isLoading: isLoading,
                        isDisabled: !isValid
                    ) {
                        submit()
                    }
                }
                .padding(DS.spacingLG)
            }
            .pageBackground()
            .navigationTitle(mode == 0 ? L10n.Cert.selfSign : L10n.Cert.generateCA)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .alert(L10n.success, isPresented: $success) {
                Button(L10n.ok) { dismiss() }
            }
        }
    }

    private var selfSignForm: some View {
        Group {
            DSGroupedCard {
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    DSSectionHeader(NSLocalizedString("cert.form.section", comment: ""))
                    DSInputField(icon: AppIcon.certificate, placeholder: NSLocalizedString("cert.form.certName", comment: ""), text: $name)
                    DSInputField(icon: AppIcon.lock, placeholder: L10n.Cert.password, text: $password)
                }
                .padding(DS.spacingLG)
            }

            DSGroupedCard {
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    DSSectionHeader(NSLocalizedString("cert.selfSign.subject", comment: ""))
                    DSInputField(icon: AppIcon.user, placeholder: NSLocalizedString("cert.selfSign.cn", comment: ""), text: $commonName)
                    DSInputField(icon: AppIcon.email, placeholder: NSLocalizedString("cert.selfSign.email", comment: ""), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                .padding(DS.spacingLG)
            }
        }
    }

    private var caForm: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                DSSectionHeader(NSLocalizedString("cert.ca.section", comment: ""))
                DSInputField(icon: AppIcon.user, placeholder: NSLocalizedString("cert.selfSign.cn", comment: ""), text: $commonName)
                DSInputField(icon: AppIcon.work, placeholder: NSLocalizedString("cert.ca.org", comment: ""), text: $organization)
                DSInputField(icon: AppIcon.category, placeholder: NSLocalizedString("cert.ca.country", comment: ""), text: $country)
                    .textInputAutocapitalization(.characters)
            }
            .padding(DS.spacingLG)
        }
    }

    private var isValid: Bool {
        if mode == 0 {
            return !name.isEmpty && !commonName.isEmpty && !password.isEmpty
        } else {
            return !commonName.isEmpty
        }
    }

    private func submit() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                if mode == 0 {
                    try await vm.selfSign(
                        name: name, password: password,
                        commonName: commonName,
                        email: email.isEmpty ? nil : email
                    )
                } else {
                    try await vm.generateCA(
                        commonName: commonName,
                        organization: organization.isEmpty ? nil : organization,
                        country: country.isEmpty ? nil : country
                    )
                }
                success = true
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
