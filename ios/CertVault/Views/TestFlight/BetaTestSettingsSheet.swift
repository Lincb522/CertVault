import SwiftUI

struct BetaTestSettingsSheet: View {
    let appId: String
    let accountId: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var reviewInfo: BetaReviewInfo?
    @State private var licenseInfo: BetaLicenseInfo?
    @State private var isLoading = true

    @State private var contactEmail = ""
    @State private var contactFirstName = ""
    @State private var contactLastName = ""
    @State private var contactPhone = ""
    @State private var demoAccountName = ""
    @State private var demoAccountPassword = ""
    @State private var demoAccountRequired = false
    @State private var notes = ""
    @State private var licenseText = ""

    @State private var isSaving = false
    @State private var resultMsg: String?
    @State private var isError = false

    private let service = AppStoreConnectService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("审核信息").tag(0)
                    Text("许可协议").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else {
                    Form {
                        if selectedTab == 0 {
                            reviewInfoSection
                        } else {
                            licenseSection
                        }

                        if let msg = resultMsg {
                            Section {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(isError ? Color.dsAccentPink : Color.dsAccent)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .pageBackground()
            .navigationTitle("测试条件设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .sheetStyle()
        .presentationDetents([.large])
        .task { await loadData() }
    }

    // MARK: - Review Info

    @ViewBuilder
    private var reviewInfoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("审核联系人和演示账号信息", systemImage: "person.badge.shield.checkmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                Text("外部测试需要通过 Apple 审核，请填写联系信息和演示账号")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
        }

        Section("联系人信息") {
            TextField("联系人邮箱", text: $contactEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("联系人名字", text: $contactFirstName)
            TextField("联系人姓氏", text: $contactLastName)
            TextField("联系人电话", text: $contactPhone)
                .keyboardType(.phonePad)
        }

        Section("演示账号") {
            Toggle("需要演示账号", isOn: $demoAccountRequired)
            if demoAccountRequired {
                TextField("演示账号用户名", text: $demoAccountName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("演示账号密码", text: $demoAccountPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }

        Section("审核备注") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
            Text("向审核人员说明如何测试你的 App（可选）")
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
    }

    // MARK: - License

    @ViewBuilder
    private var licenseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Beta 许可协议", systemImage: "doc.text")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                Text("测试员在安装 Beta 版本前会看到此协议")
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
        }

        Section("协议内容") {
            TextEditor(text: $licenseText)
                .frame(minHeight: 160)
        }

        if licenseText.isEmpty {
            Section {
                Button {
                    licenseText = defaultLicenseText
                } label: {
                    HStack(spacing: 4) {
                        HIcon(AppIcon.docText)
                        Text("使用默认模板")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.dsAccentBlue)
                }
            }
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        async let r = service.getBetaReviewInfo(appId: appId, accountId: accountId)
        async let l = service.getBetaLicense(appId: appId, accountId: accountId)

        reviewInfo = try? await r
        licenseInfo = try? await l

        if let info = reviewInfo {
            contactEmail = info.contact_email ?? ""
            contactFirstName = info.contact_first_name ?? ""
            contactLastName = info.contact_last_name ?? ""
            contactPhone = info.contact_phone ?? ""
            demoAccountName = info.demo_account_name ?? ""
            demoAccountPassword = info.demo_account_password ?? ""
            demoAccountRequired = info.demo_account_required ?? false
            notes = info.notes ?? ""
        }
        if let license = licenseInfo {
            licenseText = license.agreement_text ?? ""
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        resultMsg = nil
        isError = false
        do {
            if selectedTab == 0 {
                var update = BetaReviewInfoUpdate(account_id: accountId)
                update.contact_email = contactEmail.isEmpty ? nil : contactEmail
                update.contact_first_name = contactFirstName.isEmpty ? nil : contactFirstName
                update.contact_last_name = contactLastName.isEmpty ? nil : contactLastName
                update.contact_phone = contactPhone.isEmpty ? nil : contactPhone
                update.demo_account_name = demoAccountName.isEmpty ? nil : demoAccountName
                update.demo_account_password = demoAccountPassword.isEmpty ? nil : demoAccountPassword
                update.demo_account_required = demoAccountRequired
                update.notes = notes.isEmpty ? nil : notes
                try await service.updateBetaReviewInfo(appId: appId, accountId: accountId, info: update)
                resultMsg = "审核信息已保存"
            } else {
                try await service.updateBetaLicense(appId: appId, accountId: accountId, text: licenseText)
                resultMsg = "许可协议已保存"
            }
        } catch {
            resultMsg = "保存失败: \(error.localizedDescription)"
            isError = true
        }
        isSaving = false
    }

    private var defaultLicenseText: String {
        """
        Beta Software License Agreement

        This is a beta version of the software ("Beta Software") and is provided "as is" without warranty of any kind.

        By installing and using this Beta Software, you agree to the following terms:

        1. The Beta Software is provided for testing and evaluation purposes only.
        2. You acknowledge that the Beta Software may contain bugs, errors, and other issues.
        3. You agree to provide feedback and report any issues encountered during testing.
        4. The Beta Software may not be distributed, shared, or made available to third parties.
        5. The developer reserves the right to modify or discontinue the Beta Software at any time.
        6. Your use of the Beta Software is at your own risk.

        Thank you for participating in our beta testing program!
        """
    }
}
