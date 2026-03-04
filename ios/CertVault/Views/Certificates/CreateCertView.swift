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
                    Section("账号") {
                        Picker("选择账号", selection: $vm.selectedAccountId) {
                            ForEach(vm.accounts) { acc in
                                Text(acc.displayName).tag(acc.id)
                            }
                        }
                    }
                }

                Section {
                    Picker("证书类型", selection: $selectedType) {
                        ForEach(vm.certTypes) { type in
                            VStack(alignment: .leading) {
                                Text(type.label)
                            }
                            .tag(type.value)
                        }
                    }
                } header: {
                    Text("证书类型")
                } footer: {
                    if let type = vm.certTypes.first(where: { $0.value == selectedType }) {
                        Text(type.desc ?? "")
                    }
                }

                Section("证书信息") {
                    TextField("证书名称（可选）", text: $name)
                    HStack {
                        Text("P12 密码")
                        Spacer()
                        TextField("密码", text: $password)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                if let quota = vm.quotas[selectedType] {
                    Section("配额信息") {
                        HStack {
                            Text("已使用")
                            Spacer()
                            Text("\(quota.used) / \(quota.limit)")
                                .foregroundStyle(quota.available > 0 ? .green : .red)
                        }
                        if quota.available <= 0 {
                            HStack {
                                HIcon(AppIcon.warning)
                                    .foregroundStyle(.orange)
                                Text("配额已满，创建时将自动撤销最旧的同类证书")
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
            .navigationTitle("创建证书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create(revokeAndRecreate: false) }
                        .disabled(isLoading)
                }
            }
            .alert("证书配额已满", isPresented: $showRevokeConfirm) {
                Button("撤销并重建", role: .destructive) {
                    create(revokeAndRecreate: true)
                }
                Button("取消", role: .cancel) {}
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
