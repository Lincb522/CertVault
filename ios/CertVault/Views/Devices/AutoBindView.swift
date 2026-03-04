import SwiftUI
import HiconIcons

struct AutoBindView: View {
    @ObservedObject var vm: DeviceViewModel
    @Environment(\.dismiss) private var dismiss

    var prefillName: String = ""
    var prefillUDID: String = ""

    @State private var deviceName = ""
    @State private var udid = ""
    @State private var bundleId = ""
    @State private var bundleName = ""
    @State private var selectedBindType = BindType.iosDev
    @State private var password = "123456"

    enum BindType: String, CaseIterable, Identifiable {
        case iosDev       = "ios_dev"
        case iosDist      = "ios_dist"
        case iosAdhoc     = "ios_adhoc"
        case iosInhouse   = "ios_inhouse"
        case macDev       = "mac_dev"
        case macDist      = "mac_dist"
        case macDirect    = "mac_direct"
        case tvosDev      = "tvos_dev"
        case tvosDist     = "tvos_dist"
        case tvosAdhoc    = "tvos_adhoc"
        case tvosInhouse  = "tvos_inhouse"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .iosDev:      return "iOS 开发"
            case .iosDist:     return "iOS App Store 发布"
            case .iosAdhoc:    return "iOS Ad Hoc 分发"
            case .iosInhouse:  return "iOS 企业内部分发"
            case .macDev:      return "macOS 开发"
            case .macDist:     return "macOS App Store 发布"
            case .macDirect:   return "macOS 直接分发"
            case .tvosDev:     return "tvOS 开发"
            case .tvosDist:    return "tvOS App Store 发布"
            case .tvosAdhoc:   return "tvOS Ad Hoc 分发"
            case .tvosInhouse: return "tvOS 企业内部分发"
            }
        }

        var desc: String {
            switch self {
            case .iosDev:      return "Xcode 真机调试、开发测试"
            case .iosDist:     return "提交 App Store 审核发布"
            case .iosAdhoc:    return "分发到指定设备（最多100台）"
            case .iosInhouse:  return "企业账号内部分发，无设备限制"
            case .macDev:      return "macOS App 开发调试"
            case .macDist:     return "提交 Mac App Store 发布"
            case .macDirect:   return "Mac App Store 外直接分发"
            case .tvosDev:     return "Apple TV App 开发调试"
            case .tvosDist:    return "提交 tvOS App Store 发布"
            case .tvosAdhoc:   return "Apple TV 测试分发"
            case .tvosInhouse: return "Apple TV 企业内部分发"
            }
        }

        var certType: String {
            switch self {
            case .iosDev:                             return "IOS_DEVELOPMENT"
            case .iosDist, .iosAdhoc, .iosInhouse:    return "IOS_DISTRIBUTION"
            case .macDev:                              return "MAC_APP_DEVELOPMENT"
            case .macDist, .macDirect:                 return "MAC_APP_DISTRIBUTION"
            case .tvosDev:                             return "IOS_DEVELOPMENT"
            case .tvosDist, .tvosAdhoc, .tvosInhouse:  return "IOS_DISTRIBUTION"
            }
        }

        var profileType: String {
            switch self {
            case .iosDev:      return "IOS_APP_DEVELOPMENT"
            case .iosDist:     return "IOS_APP_STORE"
            case .iosAdhoc:    return "IOS_APP_ADHOC"
            case .iosInhouse:  return "IOS_APP_INHOUSE"
            case .macDev:      return "MAC_APP_DEVELOPMENT"
            case .macDist:     return "MAC_APP_STORE"
            case .macDirect:   return "MAC_APP_DIRECT"
            case .tvosDev:     return "TVOS_APP_DEVELOPMENT"
            case .tvosDist:    return "TVOS_APP_STORE"
            case .tvosAdhoc:   return "TVOS_APP_ADHOC"
            case .tvosInhouse: return "TVOS_APP_INHOUSE"
            }
        }

        var platform: String {
            switch self {
            case .iosDev, .iosDist, .iosAdhoc, .iosInhouse: return "IOS"
            case .macDev, .macDist, .macDirect:               return "MAC_OS"
            case .tvosDev, .tvosDist, .tvosAdhoc, .tvosInhouse: return "IOS"
            }
        }

        var icon: UIImage {
            switch self {
            case .iosDev, .iosDist, .iosAdhoc, .iosInhouse: return AppIcon.device
            case .macDev, .macDist, .macDirect:               return AppIcon.device
            case .tvosDev, .tvosDist, .tvosAdhoc, .tvosInhouse: return AppIcon.device
            }
        }

        var color: Color {
            switch self {
            case .iosDev:      return .dsAccentBlue
            case .iosDist:     return .dsAccentPurple
            case .iosAdhoc:    return .dsAccentOrange
            case .iosInhouse:  return .dsAccentPink
            case .macDev:      return .dsAccent
            case .macDist:     return .dsAccentPurple
            case .macDirect:   return .dsAccentOrange
            case .tvosDev:     return .dsAccentBlue
            case .tvosDist:    return .dsAccentPurple
            case .tvosAdhoc:   return .dsAccentOrange
            case .tvosInhouse: return .dsAccentPink
            }
        }

        var categoryLabel: String {
            switch self {
            case .iosDev, .iosDist, .iosAdhoc, .iosInhouse: return "iOS"
            case .macDev, .macDist, .macDirect:               return "macOS"
            case .tvosDev, .tvosDist, .tvosAdhoc, .tvosInhouse: return "tvOS"
            }
        }

        static var iosTypes: [BindType]   { [.iosDev, .iosDist, .iosAdhoc, .iosInhouse] }
        static var macTypes: [BindType]   { [.macDev, .macDist, .macDirect] }
        static var tvosTypes: [BindType]  { [.tvosDev, .tvosDist, .tvosAdhoc, .tvosInhouse] }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isBinding || vm.bindResult != nil || vm.bindError != nil {
                    progressView
                } else {
                    formView
                }
            }
            .navigationTitle("一键绑定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.bindResult != nil ? "完成" : "取消") { dismiss() }
                }
            }
        }
    }

    private var formView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vm.accounts.count > 1 {
                    accountSection
                }
                bindTypeSection
                deviceInfoSection
                appInfoSection
                passwordSection
                bindButton
            }
            .padding(16)
        }
        .pageBackground()
        .onAppear {
            if !prefillName.isEmpty && deviceName.isEmpty {
                deviceName = prefillName
            }
            if !prefillUDID.isEmpty && udid.isEmpty {
                udid = prefillUDID
            }
            if bundleId.isEmpty {
                let rand = Int.random(in: 1000...9999)
                bundleId = "zj-\(rand).zijiu522.cn"
                bundleName = "zj-\(rand)"
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("账号", icon: AppIcon.account, color: .dsAccentBlue)
            Picker("选择账号", selection: $vm.selectedAccountId) {
                ForEach(vm.accounts) { acc in
                    Text(acc.displayName).tag(acc.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.dsAccentBlue)
        }
        .cardStyle()
    }

    // MARK: - Bind Type

    private var bindTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("绑定类型", icon: AppIcon.certificate, color: .dsAccentPurple)

            Text("选择要创建的证书和描述文件类型")
                .font(.caption)
                .foregroundStyle(Color.dsMuted)

            platformGroup("iOS", types: BindType.iosTypes)
            platformGroup("macOS", types: BindType.macTypes)
            platformGroup("tvOS", types: BindType.tvosTypes)
        }
        .cardStyle()
    }

    private func platformGroup(_ title: String, types: [BindType]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dsMuted)
                .padding(.top, 4)

            ForEach(types) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBindType = type
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selectedBindType == type ? type.color : Color.clear)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(selectedBindType == type ? type.color : Color.dsMuted.opacity(0.5), lineWidth: 2)
                            )
                            .overlay {
                                if selectedBindType == type {
                                    HIcon(AppIcon.tick)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                }
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.dsText)
                            Text(type.desc)
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        selectedBindType == type
                            ? type.color.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Device Info

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("设备信息", icon: AppIcon.device, color: .dsAccent)
            VStack(spacing: 0) {
                inputRow("设备名称", text: $deviceName, placeholder: "iPhone 15 Pro")
                Divider()
                inputRow("UDID", text: $udid, placeholder: "00008030-001A29D82280802E", monospaced: true)
            }
            .background(Color.dsSurfaceLight, in: RoundedRectangle(cornerRadius: 10))
        }
        .cardStyle()
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("应用信息", icon: AppIcon.bundleID, color: .dsAccentOrange)
            VStack(spacing: 0) {
                inputRow("Bundle ID", text: $bundleId, placeholder: "com.example.app", monospaced: true)
                Divider()
                inputRow("应用名称", text: $bundleName, placeholder: "MyApp")
            }
            .background(Color.dsSurfaceLight, in: RoundedRectangle(cornerRadius: 10))
        }
        .cardStyle()
    }

    // MARK: - Password

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("P12 密码", icon: AppIcon.lock, color: .dsAccentPink)
            inputRow("密码", text: $password, placeholder: "123456", monospaced: true)
                .background(Color.dsSurfaceLight, in: RoundedRectangle(cornerRadius: 10))
        }
        .cardStyle()
    }

    // MARK: - Bind Button

    private var bindButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await vm.autoBind(
                        name: deviceName, udid: udid,
                        bundleId: bundleId, bundleName: bundleName,
                        certType: selectedBindType.certType,
                        profileType: selectedBindType.profileType,
                        platform: selectedBindType.platform,
                        password: password
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    HIcon(AppIcon.link).font(.body)
                    Text("开始一键绑定")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [selectedBindType.color, selectedBindType.color.opacity(0.7)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.5)

            HStack(spacing: 4) {
                Text("将创建")
                    .foregroundStyle(Color.dsMuted)
                Text(selectedBindType.label)
                    .foregroundStyle(selectedBindType.color)
                    .fontWeight(.medium)
                Text("类型证书")
                    .foregroundStyle(Color.dsMuted)
            }
            .font(.caption)
        }
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 24) {
            if vm.isBinding {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 40)
                Text("正在执行一键绑定...")
                    .font(.headline)
            }

            if !vm.bindSteps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(vm.bindSteps.enumerated()), id: \.offset) { _, step in
                        HStack(spacing: 12) {
                            HIcon(AppIcon.check)
                                .foregroundStyle(.green)
                            Text(step)
                                .font(.subheadline)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut, value: vm.bindSteps.count)
                .padding()
            }

            if vm.bindResult != nil && !vm.isBinding {
                HIcon(AppIcon.check)
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("绑定成功！")
                    .font(.title2.bold())
                Text("设备已注册，证书和描述文件已生成")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let error = vm.bindError {
                HIcon(AppIcon.close)
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                Text("绑定失败")
                    .font(.title2.bold())
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: UIImage, color: Color) -> some View {
        HStack(spacing: 8) {
            HIcon(icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.dsText)
        }
    }

    private func inputRow(_ label: String, text: Binding<String>, placeholder: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                .font(monospaced ? .subheadline.monospaced() : .subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var isValid: Bool {
        !deviceName.isEmpty && !udid.isEmpty && !bundleId.isEmpty && !bundleName.isEmpty
    }
}
