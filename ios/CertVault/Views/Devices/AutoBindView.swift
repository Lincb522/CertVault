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
            case .iosDev:      return .dsBlue
            case .iosDist:     return .dsPurple
            case .iosAdhoc:    return .dsOrange
            case .iosInhouse:  return .dsPink
            case .macDev:      return .dsGreen
            case .macDist:     return .dsPurple
            case .macDirect:   return .dsOrange
            case .tvosDev:     return .dsBlue
            case .tvosDist:    return .dsPurple
            case .tvosAdhoc:   return .dsOrange
            case .tvosInhouse: return .dsPink
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
            .navigationTitle(L10n.Device.autoBind)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(vm.bindResult != nil ? L10n.done : L10n.cancel) { dismiss() }
                }
            }
        }
    }

    private var formView: some View {
        ScrollView {
            VStack(spacing: DS.spacingLG) {
                if vm.accounts.count > 1 {
                    accountSection
                }
                bindTypeSection
                deviceInfoSection
                appInfoSection
                passwordSection
                bindButton
            }
            .padding(DS.spacingLG)
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
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                sectionHeader(L10n.account, icon: AppIcon.account, color: .dsBlue)
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

    // MARK: - Bind Type

    private var bindTypeSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                sectionHeader(NSLocalizedString("autoBind.section.bindType", comment: ""), icon: AppIcon.certificate, color: .dsPurple)

                Text(L10n.AutoBind.desc)
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)

                platformGroup("iOS", types: BindType.iosTypes)
                platformGroup("macOS", types: BindType.macTypes)
                platformGroup("tvOS", types: BindType.tvosTypes)
            }
            .padding(DS.spacingLG)
        }
    }

    private func platformGroup(_ title: String, types: [BindType]) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.top, DS.spacingXS)

            ForEach(types) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBindType = type
                    }
                } label: {
                    HStack(spacing: DS.spacingMD) {
                        Circle()
                            .fill(selectedBindType == type ? type.color : Color.clear)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(selectedBindType == type ? type.color : Color.dsTextTertiary.opacity(0.5), lineWidth: 2)
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
                                .foregroundStyle(Color.dsTextSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, DS.spacingSM)
                    .padding(.horizontal, DS.spacingMD)
                    .background(
                        selectedBindType == type
                            ? type.color.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: DS.radiusMD)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Device Info

    private var deviceInfoSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                sectionHeader(NSLocalizedString("autoBind.section.deviceInfo", comment: ""), icon: AppIcon.device, color: .dsGreen)
                VStack(spacing: 0) {
                    inputRow(L10n.Device.formName, text: $deviceName, placeholder: "iPhone 15 Pro")
                    DSDivider(leadingPadding: 0)
                    inputRow(L10n.Device.formUdid, text: $udid, placeholder: "00008030-001A29D82280802E", monospaced: true)
                }
                .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
            }
            .padding(DS.spacingLG)
        }
    }

    // MARK: - App Info

    private var appInfoSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                sectionHeader(NSLocalizedString("autoBind.section.appInfo", comment: ""), icon: AppIcon.bundleID, color: .dsOrange)
                VStack(spacing: 0) {
                    inputRow(L10n.Profile.bundleId, text: $bundleId, placeholder: "com.example.app", monospaced: true)
                    DSDivider(leadingPadding: 0)
                    inputRow(NSLocalizedString("autoBind.appName", comment: ""), text: $bundleName, placeholder: "MyApp")
                }
                .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
            }
            .padding(DS.spacingLG)
        }
    }

    // MARK: - Password

    private var passwordSection: some View {
        DSGroupedCard {
            VStack(alignment: .leading, spacing: DS.spacingMD) {
                sectionHeader(L10n.Cert.password, icon: AppIcon.lock, color: .dsPink)
                inputRow(NSLocalizedString("autoBind.password", comment: ""), text: $password, placeholder: "123456", monospaced: true)
                    .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
            }
            .padding(DS.spacingLG)
        }
    }

    // MARK: - Bind Button

    private var bindButton: some View {
        VStack(spacing: DS.spacingSM) {
            DSPrimaryButton(title: L10n.AutoBind.start, isDisabled: !isValid) {
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
            }

            HStack(spacing: DS.spacingXS) {
                Text(L10n.AutoBind.willCreate)
                    .foregroundStyle(Color.dsTextSecondary)
                Text(selectedBindType.label)
                    .foregroundStyle(selectedBindType.color)
                    .fontWeight(.medium)
                Text(L10n.AutoBind.typeCert)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            .font(.caption)
        }
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: DS.spacing2XL) {
            if vm.isBinding {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 40)
                Text(L10n.AutoBind.running)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
            }

            if !vm.bindSteps.isEmpty {
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    ForEach(Array(vm.bindSteps.enumerated()), id: \.offset) { _, step in
                        HStack(spacing: DS.spacingMD) {
                            HIcon(AppIcon.check)
                                .foregroundStyle(Color.dsSuccess)
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Color.dsText)
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
                    .foregroundStyle(Color.dsSuccess)
                Text(L10n.AutoBind.success)
                    .font(.title2.bold())
                    .foregroundStyle(Color.dsText)
                Text(L10n.AutoBind.successDesc)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            if let error = vm.bindError {
                HIcon(AppIcon.close)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.dsDanger)
                Text(L10n.AutoBind.failed)
                    .font(.title2.bold())
                    .foregroundStyle(Color.dsText)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: UIImage, color: Color) -> some View {
        HStack(spacing: DS.spacingSM) {
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
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                .font(monospaced ? .subheadline.monospaced() : .subheadline)
                .foregroundStyle(Color.dsText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, DS.spacingMD)
        .padding(.vertical, DS.spacingMD)
    }

    private var isValid: Bool {
        !deviceName.isEmpty && !udid.isEmpty && !bundleId.isEmpty && !bundleName.isEmpty
    }
}
