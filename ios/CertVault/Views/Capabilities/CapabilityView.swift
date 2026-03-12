import SwiftUI
import HiconIcons

struct CapabilityView: View {
    @StateObject private var vm = CapabilityViewModel()
    @State private var showDisableAllConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                pickerSection

                if !vm.selectedBundleId.isEmpty {
                    enabledCountSection
                    presetsSection
                    capabilitiesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
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
                    .tint(Color.dsAccentBlue)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .onChange(of: vm.selectedAccountId) { _ in
                    Task { await vm.loadBundleIds() }
                }
                Divider().padding(.horizontal, 16)
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
                .tint(Color.dsAccentBlue)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .onChange(of: vm.selectedBundleId) { _ in
                Task { await vm.loadEnabled() }
            }
        }
        .glassCard(cornerRadius: 14)
    }

    private var enabledCountSection: some View {
        HStack {
            Text(L10n.Capability.enabled)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.dsText)
            Spacer()
            let count = vm.enabledCapabilities.filter(\.isEnabled).count
            let total = vm.availableCapabilities.count
            Text("\(count) / \(total)")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(count > 0 ? Color.dsAccent : Color.dsMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassCard(cornerRadius: 14)
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(NSLocalizedString("capability.presets", comment: ""))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(vm.presets.keys.sorted()), id: \.self) { name in
                        Button {
                            if let types = vm.presets[name] {
                                Task { await vm.applyPreset(types) }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                HIcon(iconForPreset(name))
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                Text(labelForPreset(name))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 70, height: 60)
                            .background(gradientForPreset(name), in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showDisableAllConfirm = true
                    } label: {
                        VStack(spacing: 4) {
                            HIcon(AppIcon.close)
                                .font(.title3)
                                .foregroundStyle(.white)
                            Text(L10n.Capability.disableAll)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 70, height: 60)
                        .background(
                            LinearGradient(colors: [Color.dsAccentPink, Color.dsAccentPink.opacity(0.7)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var capabilitiesSection: some View {
        ForEach(groupedCategories, id: \.0) { category, capabilities in
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(category)
                VStack(spacing: 0) {
                    ForEach(Array(capabilities.enumerated()), id: \.element.id) { index, cap in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cap.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                if let desc = cap.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption2)
                                        .foregroundStyle(Color.dsMuted)
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
                                .tint(Color.dsAccentBlue)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if index < capabilities.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .glassCard(cornerRadius: 14)
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
        case "basic":
            return LinearGradient(colors: [.dsAccentBlue, .dsAccentBlue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "social":
            return LinearGradient(colors: [.dsAccentPurple, .dsAccentPurple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "game":
            return LinearGradient(colors: [.dsAccentOrange, .dsAccentOrange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "enterprise":
            return LinearGradient(colors: [.dsAccent, .dsAccent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.dsAccentCyan, .dsAccentCyan.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
