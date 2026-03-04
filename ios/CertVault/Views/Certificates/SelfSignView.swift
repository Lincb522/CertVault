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
                Picker("操作", selection: $mode) {
                    Text("自签证书").tag(0)
                    Text("生成 CA").tag(1)
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
            .navigationTitle(mode == 0 ? "自签证书" : "生成 CA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == 0 ? "生成" : "创建 CA") { submit() }
                        .disabled(isLoading || !isValid)
                }
            }
            .alert("操作成功", isPresented: $success) {
                Button("好") { dismiss() }
            }
        }
    }

    private var selfSignForm: some View {
        Group {
            Section("证书信息") {
                TextField("证书名称", text: $name)
                TextField("P12 密码", text: $password)
            }
            Section("主题信息") {
                TextField("通用名称 (CN)", text: $commonName)
                TextField("邮箱（可选）", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
    }

    private var caForm: some View {
        Section("CA 信息") {
            TextField("通用名称 (CN)", text: $commonName)
            TextField("组织（可选）", text: $organization)
            TextField("国家代码", text: $country)
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
