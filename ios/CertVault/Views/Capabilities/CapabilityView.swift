import SwiftUI
import HiconIcons

struct CapabilityView: View {
    @StateObject private var vm = CapabilityViewModel()
    @State private var showDisableAllConfirm = false

    var body: some View {
        List {
            pickerSection

            if !vm.selectedBundleId.isEmpty {
                enabledCountSection
                presetsSection
                capabilitiesSection
            }
        }
        .listStyle(.insetGrouped)
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
        Section {
            if vm.accounts.count > 1 {
                Picker(L10n.account, selection: $vm.selectedAccountId) {
                    ForEach(vm.accounts) { acc in
                        Text(acc.displayName).tag(acc.id)
                    }
                }
                .onChange(of: vm.selectedAccountId) { _ in
                    Task { await vm.loadBundleIds() }
                }
            }

            Picker(L10n.Profile.bundleId, selection: $vm.selectedBundleId) {
                Text(L10n.select).tag("")
                ForEach(vm.bundleIds) { bid in
                    Text(bid.identifier ?? bid.displayName).tag(bid.id)
                }
            }
            .onChange(of: vm.selectedBundleId) { _ in
                Task { await vm.loadEnabled() }
            }
        }
    }

    private var enabledCountSection: some View {
        Section {
            HStack {
                Text(L10n.Capability.enabled)
                    .font(.subheadline)
                Spacer()
                let count = vm.enabledCapabilities.filter(\.isEnabled).count
                let total = vm.availableCapabilities.count
                Text("\(count) / \(total)")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(count > 0 ? Color.dsAccent : Color.dsMuted)
            }
        }
    }

    private var presetsSection: some View {
        Section(NSLocalizedString("capability.presets", comment: "")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(vm.presets.keys.sorted()), id: \.self) { name in
                        Button {
                            if let types = vm.presets[name] {
                                Task { await vm.applyPreset(types) }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                HIcon(iconForPreset(name))
                                    .font(.title3)
                                Text(labelForPreset(name))
                                    .font(.caption2)
                            }
                            .frame(width: 70, height: 60)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showDisableAllConfirm = true
                    } label: {
                        VStack(spacing: 4) {
                            HIcon(AppIcon.close)
                                .font(.title3)
                                .foregroundStyle(.red)
                            Text(L10n.Capability.disableAll)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        .frame(width: 70, height: 60)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    private var capabilitiesSection: some View {
        ForEach(groupedCategories, id: \.0) { category, capabilities in
            Section(category) {
                ForEach(capabilities) { cap in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cap.name)
                                .font(.subheadline)
                            if let desc = cap.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
}
