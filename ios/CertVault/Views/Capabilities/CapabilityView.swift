import SwiftUI
import HiconIcons

struct CapabilityView: View {
    @StateObject private var vm = CapabilityViewModel()
    @State private var showDisableAllConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingXL) {
                pickerSection

                if !vm.selectedBundleId.isEmpty {
                    enabledCountSection
                    presetsSection
                    capabilitiesSection
                }
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacingXL)
        }
        .pageBackground()
        .navigationTitle(L10n.Capability.title)
        .overlay {
            if vm.isLoading {
                LoadingView()
            }
        }
        .task {
            await vm.loadAccounts()
            await vm.loadAvailable()
        }
        .alert(L10n.Capability.disableAllTitle, isPresented: $showDisableAllConfirm) {
            Button(L10n.Capability.disableAll, role: .destructive) {
                Task { await vm.disableAll() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Capability.disableAllMessage)
        }
        .alert(L10n.Capability.failedTitle, isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var pickerSection: some View {
        DSGroupedCard {
            VStack(spacing: 0) {
                if vm.accounts.count > 1 {
                    HStack {
                        Text(L10n.account)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.dsText)
                        Spacer()
                        Picker(L10n.account, selection: $vm.selectedAccountId) {
                            ForEach(vm.accounts) { acc in
                                Text(acc.displayName).tag(acc.id)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.dsBrand)
                    }
                    .padding(.vertical, DS.spacingMD)
                    .padding(.horizontal, DS.spacingLG)
                    .onChange(of: vm.selectedAccountId) { _ in
                        Task { await vm.loadBundleIds() }
                    }
                    DSDivider()
                }

                HStack {
                    Text(L10n.Profile.bundleId)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
                    Spacer()
                    Picker(L10n.Profile.bundleId, selection: $vm.selectedBundleId) {
                        Text(L10n.select).tag("")
                        ForEach(vm.bundleIds) { bid in
                            Text(bid.identifier ?? bid.displayName).tag(bid.id)
                        }
                    }
                    .labelsHidden()
                    .tint(Color.dsBrand)
                }
                .padding(.vertical, DS.spacingMD)
                .padding(.horizontal, DS.spacingLG)
                .onChange(of: vm.selectedBundleId) { _ in
                    Task { await vm.loadEnabled() }
                }
            }
        }
    }

    private var enabledCountSection: some View {
        DSGroupedCard {
            HStack {
                Text(L10n.Capability.enabled)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                Spacer()
                let count = vm.enabledCapabilities.filter(\.isEnabled).count
                let total = vm.availableCapabilities.count
                Text("\(count) / \(total)")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(count > 0 ? Color.dsGreen : Color.dsTextSecondary)
            }
            .padding(.vertical, DS.spacingMD)
            .padding(.horizontal, DS.spacingLG)
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            DSSectionHeader(NSLocalizedString("capability.presets", comment: ""))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingSM) {
                    ForEach(Array(vm.presets.keys.sorted()), id: \.self) { name in
                        Button {
                            if let types = vm.presets[name] {
                                Task { await vm.applyPreset(types) }
                            }
                        } label: {
                            VStack(spacing: DS.spacingXS) {
                                HIcon(iconForPreset(name))
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                Text(labelForPreset(name))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 70, height: 60)
                            .background(gradientForPreset(name), in: RoundedRectangle(cornerRadius: DS.radiusSM))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.dsPressed)
                    }

                    Button {
                        showDisableAllConfirm = true
                    } label: {
                        VStack(spacing: DS.spacingXS) {
                            HIcon(AppIcon.close)
                                .font(.title3)
                                .foregroundStyle(.white)
                            Text(L10n.Capability.disableAll)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 70, height: 60)
                        .background(Color.dsGradientPink, in: RoundedRectangle(cornerRadius: DS.radiusSM))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.dsPressed)
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var capabilitiesSection: some View {
        ForEach(groupedCategories, id: \.0) { category, capabilities in
            VStack(alignment: .leading, spacing: DS.spacingSM) {
                DSSectionHeader(category)
                DSGroupedCard {
                    ForEach(Array(capabilities.enumerated()), id: \.element.id) { index, cap in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cap.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                if let desc = cap.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsTextSecondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            if vm.togglingTypes.contains(cap.type) {
                                ProgressView().controlSize(.small)
                            } else {
                                Toggle("", isOn: .init(
                                    get: { vm.isEnabled(cap.type) },
                                    set: { _ in Task { await vm.toggle(cap.type) } }
                                ))
                                .labelsHidden()
                                .tint(Color.dsBrand)
                            }
                        }
                        .padding(.vertical, DS.spacingMD)
                        .padding(.horizontal, DS.spacingLG)

                        if index < capabilities.count - 1 {
                            DSDivider()
                        }
                    }
                }
            }
        }
    }

    private var groupedCategories: [(String, [AvailableCapability])] {
        let categoryOrder = ["common", "payment", "media", "device", "network", "security"]
        let categoryLabels: [String: String] = [
            "common": NSLocalizedString("capability.cat.common", comment: ""),
            "payment": NSLocalizedString("capability.cat.payment", comment: ""),
            "media": NSLocalizedString("capability.cat.media", comment: ""),
            "device": NSLocalizedString("capability.cat.device", comment: ""),
            "network": NSLocalizedString("capability.cat.network", comment: ""),
            "security": NSLocalizedString("capability.cat.security", comment: ""),
        ]

        var grouped: [String: [AvailableCapability]] = [:]
        for cap in vm.availableCapabilities {
            let cat = cap.category ?? "other"
            grouped[cat, default: []].append(cap)
        }

        var result: [(String, [AvailableCapability])] = []
        for key in categoryOrder where grouped[key] != nil {
            let label = categoryLabels[key] ?? key
            result.append((label, grouped.removeValue(forKey: key)!))
        }
        for (key, caps) in grouped.sorted(by: { $0.key < $1.key }) {
            let label = categoryLabels[key] ?? key
            result.append((label, caps))
        }
        return result
    }

    private func iconForPreset(_ name: String) -> UIImage {
        switch name.lowercased() {
        case "basic": return AppIcon.star
        case "social": return AppIcon.group
        case "game": return AppIcon.game
        case "enterprise": return AppIcon.work
        default: return AppIcon.category
        }
    }

    private func labelForPreset(_ name: String) -> String {
        switch name.lowercased() {
        case "basic": return NSLocalizedString("capability.preset.basic", comment: "")
        case "social": return NSLocalizedString("capability.preset.social", comment: "")
        case "game": return NSLocalizedString("capability.preset.game", comment: "")
        case "enterprise": return NSLocalizedString("capability.preset.enterprise", comment: "")
        default: return name
        }
    }

    private func gradientForPreset(_ name: String) -> LinearGradient {
        switch name.lowercased() {
        case "basic": return Color.dsGradientBlue
        case "social": return Color.dsGradientPurple
        case "game": return Color.dsGradientOrange
        case "enterprise": return Color.dsGradientGreen
        default: return Color.dsGradientCyan
        }
    }
}
