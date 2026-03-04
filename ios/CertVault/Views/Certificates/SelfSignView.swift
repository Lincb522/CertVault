import SwiftUI

struct SelfSignView: View {
    @ObservedObject var vm: CertificateViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode = 0 // 0: self-sign, 1: generate CA
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
            Form {
                Picker("", selection: $mode) {
                    Text(L10n.Cert.selfSign).tag(0)
                    Text(L10n.Cert.generateCA).tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)

                if mode == 0 {
                    selfSignForm
                } else {
                    caForm
                }

                if let err = errorMsg {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle(mode == 0 ? L10n.Cert.selfSign : L10n.Cert.generateCA)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == 0 ? NSLocalizedString("cert.selfSign.generate", comment: "") : NSLocalizedString("cert.ca.create", comment: "")) { submit() }
                        .disabled(isLoading || !isValid)
                }
            }
            .alert(L10n.success, isPresented: $success) {
                Button(L10n.ok) { dismiss() }
            }
        }
    }

    private var selfSignForm: some View {
        Group {
            Section(NSLocalizedString("cert.form.section", comment: "")) {
                TextField(NSLocalizedString("cert.form.certName", comment: ""), text: $name)
                TextField(L10n.Cert.password, text: $password)
            }
            Section(NSLocalizedString("cert.selfSign.subject", comment: "")) {
                TextField(NSLocalizedString("cert.selfSign.cn", comment: ""), text: $commonName)
                TextField(NSLocalizedString("cert.selfSign.email", comment: ""), text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
    }

    private var caForm: some View {
        Section(NSLocalizedString("cert.ca.section", comment: "")) {
            TextField(NSLocalizedString("cert.selfSign.cn", comment: ""), text: $commonName)
            TextField(NSLocalizedString("cert.ca.org", comment: ""), text: $organization)
            TextField(NSLocalizedString("cert.ca.country", comment: ""), text: $country)
                .textInputAutocapitalization(.characters)
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
