import SwiftUI
import HiconIcons
import UniformTypeIdentifiers

struct CertCheckView: View {
    @StateObject private var vm = CertCheckViewModel()
    @State private var showFilePicker = false
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                uploadSection
                optionsSection

                if vm.isValidating {
                    LoadingView(message: "正在验证...")
                        .frame(height: 120)
                }

                if let result = vm.result {
                    resultSection(result)
                }

                if let error = vm.errorMessage {
                    errorCard(error)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle("证书检查")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "p12") ?? .data,
                UTType(filenameExtension: "pfx") ?? .data,
                UTType(filenameExtension: "mobileprovision") ?? .data,
                .zip,
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                selectedFileName = url.lastPathComponent
                selectedFileData = try? Data(contentsOf: url)
            case .failure:
                break
            }
        }
        .task { await vm.loadAccounts() }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            HIcon(AppIcon.shield)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(colors: [.dsAccentBlue, .dsAccent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("验证 P12 证书和描述文件的有效性")
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
                .multilineTextAlignment(.center)

            Text("支持 .p12 / .mobileprovision / .zip")
                .font(.caption)
                .foregroundStyle(Color.dsMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
    }

    private var uploadSection: some View {
        VStack(spacing: 12) {
            Button { showFilePicker = true } label: {
                VStack(spacing: 10) {
                    HIcon(AppIcon.docUpload)
                        .font(.title2)
                        .foregroundStyle(Color.dsAccentBlue)
                    if let name = selectedFileName {
                        Text(name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                    } else {
                        Text("点击选择文件")
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(Color.dsAccentBlue.opacity(0.3))
                )
            }

            if selectedFileData != nil {
                Button {
                    guard let data = selectedFileData, let name = selectedFileName else { return }
                    Task { await vm.validate(fileData: data, fileName: name) }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isValidating {
                            ProgressView().tint(.white)
                        } else {
                            HIcon(AppIcon.shield).font(.body)
                        }
                        Text("开始验证")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.isValidating)
            }
        }
        .cardStyle()
    }

    private var optionsSection: some View {
        VStack(spacing: 10) {
            SecureField("P12 密码（默认尝试常用密码）", text: $vm.password)
                .textInputAutocapitalization(.never)

            HStack(spacing: 12) {
                HIcon(AppIcon.account).font(.body).foregroundStyle(Color.dsAccentBlue)
                Picker("Apple 在线验证", selection: $vm.selectedAccountId) {
                    Text("仅本地检查").tag("")
                    ForEach(vm.accounts) { acc in
                        Text(acc.displayName).tag(acc.id)
                    }
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func resultSection(_ result: CertCheckResponse) -> some View {
        if let matches = result.matches, !matches.isEmpty {
            matchSection(matches)
        }

        if let p12s = result.p12_results, !p12s.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("P12 证书")
                ForEach(p12s) { p12 in
                    p12Card(p12)
                }
            }
        }

        if let profiles = result.profile_results, !profiles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("描述文件")
                ForEach(profiles) { profile in
                    profileCard(profile)
                }
            }
        }

        if let errors = result.errors, !errors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("错误")
                ForEach(Array(errors.enumerated()), id: \.offset) { _, err in
                    HStack(spacing: 8) {
                        HIcon(AppIcon.warning).font(.caption).foregroundStyle(Color.dsAccentPink)
                        VStack(alignment: .leading, spacing: 2) {
                            if let file = err.file {
                                Text(file).font(.caption.weight(.medium)).foregroundStyle(Color.dsText)
                            }
                            Text(err.error ?? "未知错误").font(.caption).foregroundStyle(Color.dsAccentPink)
                        }
                    }
                }
            }
            .cardStyle()
        }
    }

    private func matchSection(_ matches: [CertProfileMatch]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("匹配结果")
            ForEach(matches) { m in
                HStack(spacing: 10) {
                    HIcon(m.both_valid == true ? AppIcon.check : AppIcon.warning)
                        .font(.body)
                        .foregroundStyle(m.both_valid == true ? Color.dsAccent : Color.dsAccentOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.bundle_id ?? "-")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                        Text(m.summary ?? "")
                            .font(.caption)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
                .cardStyle()
            }
        }
    }

    private func p12Card(_ p12: P12Result) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p12.file ?? "P12")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dsText)
                Spacer()
                StatusBadge(
                    p12.valid == true ? "有效" : "无效",
                    color: p12.valid == true ? .dsAccent : .dsAccentPink
                )
            }

            if let type = p12.type {
                infoLine("类型", type)
            }
            if let cn = p12.subject?.CN {
                infoLine("主体", cn)
            }
            if let notAfter = p12.not_after {
                infoLine("到期", notAfter)
            }
            if p12.is_expired == true {
                Text("⚠️ 证书已过期")
                    .font(.caption)
                    .foregroundStyle(Color.dsAccentPink)
            }

            if let appleStatus = p12.apple_status_text {
                appleStatusBadge(status: p12.apple_status, text: appleStatus)
            }
        }
        .cardStyle()
    }

    private func profileCard(_ profile: ProfileResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.name ?? profile.file ?? "描述文件")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dsText)
                Spacer()
                StatusBadge(
                    profile.valid == true ? "有效" : "无效",
                    color: profile.valid == true ? .dsAccent : .dsAccentPink
                )
            }

            if let type = profile.type {
                infoLine("类型", type)
            }
            if let bid = profile.bundle_id {
                infoLine("Bundle ID", bid)
            }
            if let team = profile.team_name {
                infoLine("团队", team)
            }
            if let exp = profile.expiration_date {
                infoLine("到期", exp)
            }
            if let dc = profile.device_count {
                infoLine("设备数", "\(dc)")
            }
            if profile.is_expired == true {
                Text("⚠️ 描述文件已过期")
                    .font(.caption)
                    .foregroundStyle(Color.dsAccentPink)
            }

            if let appleStatus = profile.apple_status_text {
                appleStatusBadge(status: profile.apple_status, text: appleStatus)
            }
        }
        .cardStyle()
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Color.dsMuted)
            Spacer()
            Text(value).font(.caption.weight(.medium)).foregroundStyle(Color.dsText)
        }
    }

    private func appleStatusBadge(status: String?, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status == "active" ? Color.dsAccent : Color.dsAccentPink)
                .frame(width: 6, height: 6)
            Text("Apple: \(text)")
                .font(.caption)
                .foregroundStyle(status == "active" ? Color.dsAccent : Color.dsAccentPink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (status == "active" ? Color.dsAccent : Color.dsAccentPink).opacity(0.08),
            in: Capsule()
        )
    }

    private func errorCard(_ error: String) -> some View {
        HStack(spacing: 10) {
            HIcon(AppIcon.warning)
                .font(.body)
                .foregroundStyle(Color.dsAccentPink)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(Color.dsAccentPink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.dsAccentPink.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dsAccentPink.opacity(0.2), lineWidth: 1))
    }
}
