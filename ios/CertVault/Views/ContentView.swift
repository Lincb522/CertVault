import SwiftUI
import HiconIcons

struct ContentView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                MainTabView(selectedTab: $selectedTab)
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authVM.isLoggedIn)
        .task {
            AppLogger.ui.info("🖼️ ContentView task — checking auth")
            await authVM.checkAuth()
        }
        .onChange(of: authVM.isLoggedIn) { newValue in
            AppLogger.ui.info("🖼️ isLoggedIn changed → \(newValue)")
        }
        .onChange(of: selectedTab) { newValue in
            let tabNames = [L10n.Tab.dashboard, L10n.Tab.accounts, L10n.Tab.devices, L10n.Tab.certificates, L10n.Tab.more]
            let name = newValue < tabNames.count ? tabNames[newValue] : "?\(newValue)"
            AppLogger.ui.info("🖼️ Tab switched → \(name)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { notification in
            if let tab = notification.object as? Int {
                selectedTab = tab
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        tabContent
            .tint(Color.dsAccentBlue)
    }

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 26, *) {
            TabView(selection: $selectedTab) {
                Tab(value: 0) {
                    NavigationStack { DashboardView() }
                } label: {
                    Label { Text(L10n.Tab.dashboard) } icon: { HIcon(AppIcon.dashboard) }
                }
                Tab(value: 1) {
                    NavigationStack { AccountListView() }
                } label: {
                    Label { Text(L10n.Tab.accounts) } icon: { HIcon(AppIcon.account) }
                }
                Tab(value: 2) {
                    NavigationStack { DeviceListView() }
                } label: {
                    Label { Text(L10n.Tab.devices) } icon: { HIcon(AppIcon.device) }
                }
                Tab(value: 3) {
                    NavigationStack { CertificateListView() }
                } label: {
                    Label { Text(L10n.Tab.certificates) } icon: { HIcon(AppIcon.certificate) }
                }
                Tab(value: 4) {
                    NavigationStack { MoreView() }
                } label: {
                    Label { Text(L10n.Tab.more) } icon: { HIcon(AppIcon.more) }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack { DashboardView() }
                    .tabItem { Label { Text(L10n.Tab.dashboard) } icon: { HIcon(AppIcon.dashboard) } }
                    .tag(0)
                NavigationStack { AccountListView() }
                    .tabItem { Label { Text(L10n.Tab.accounts) } icon: { HIcon(AppIcon.account) } }
                    .tag(1)
                NavigationStack { DeviceListView() }
                    .tabItem { Label { Text(L10n.Tab.devices) } icon: { HIcon(AppIcon.device) } }
                    .tag(2)
                NavigationStack { CertificateListView() }
                    .tabItem { Label { Text(L10n.Tab.certificates) } icon: { HIcon(AppIcon.certificate) } }
                    .tag(3)
                NavigationStack { MoreView() }
                    .tabItem { Label { Text(L10n.Tab.more) } icon: { HIcon(AppIcon.more) } }
                    .tag(4)
            }
        }
    }
}

// MARK: - More View

struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                moreSection(L10n.More.sectionResources, items: [
                    MoreItem(icon: AppIcon.profile, title: NSLocalizedString("more.profiles", comment: ""), subtitle: NSLocalizedString("more.profiles.sub", comment: ""), color: .dsAccentOrange) {
                        AnyView(ProfileListView())
                    },
                    MoreItem(icon: AppIcon.bundleID, title: NSLocalizedString("more.bundleId", comment: ""), subtitle: NSLocalizedString("more.bundleId.sub", comment: ""), color: .dsAccentCyan) {
                        AnyView(BundleIDListView())
                    },
                    MoreItem(icon: AppIcon.capability, title: NSLocalizedString("more.capabilities", comment: ""), subtitle: NSLocalizedString("more.capabilities.sub", comment: ""), color: .dsAccentPurple) {
                        AnyView(CapabilityView())
                    },
                ])

                moreSection(L10n.More.sectionPush, items: [
                    MoreItem(icon: AppIcon.pushKey, title: NSLocalizedString("more.pushKeys", comment: ""), subtitle: NSLocalizedString("more.pushKeys.sub", comment: ""), color: .dsAccentPink) {
                        AnyView(PushKeyListView())
                    },
                    MoreItem(icon: AppIcon.pushTest, title: NSLocalizedString("more.pushTest", comment: ""), subtitle: NSLocalizedString("more.pushTest.sub", comment: ""), color: .dsAccentBlue) {
                        AnyView(PushTestView())
                    },
                    MoreItem(icon: AppIcon.group, title: "群发推送", subtitle: "向所有注册设备批量发送推送通知", color: .dsAccentOrange) {
                        AnyView(PushBroadcastView())
                    },
                    MoreItem(icon: AppIcon.device, title: "设备管理", subtitle: "管理已注册的推送设备 Token", color: .dsAccentPurple) {
                        AnyView(PushDeviceManageView())
                    },
                    MoreItem(icon: AppIcon.clock, title: "推送历史", subtitle: "查看推送记录和统计数据", color: .dsAccentOrange) {
                        AnyView(PushHistoryView())
                    },
                    MoreItem(icon: AppIcon.settings, title: "推送设置", subtitle: "配置推送服务参数和默认值", color: .dsAccent) {
                        AnyView(PushSettingsView())
                    },
                    MoreItem(icon: AppIcon.info, title: NSLocalizedString("more.pushGuide", comment: ""), subtitle: NSLocalizedString("more.pushGuide.sub", comment: ""), color: .dsAccentCyan) {
                        AnyView(PushGuideView())
                    },
                ])

                moreSection("应用管理", items: [
                    MoreItem(icon: AppIcon.category, title: "应用管理", subtitle: "查看 App Store Connect 中的应用", color: .dsAccentBlue) {
                        AnyView(AppListView())
                    },
                    MoreItem(icon: AppIcon.pushTest, title: "TestFlight", subtitle: "管理测试分组、测试员和构建版本", color: .dsAccentPurple) {
                        AnyView(TestFlightView())
                    },
                    MoreItem(icon: AppIcon.star, title: "App Store 版本", subtitle: "管理 App Store 版本和提交审核", color: .dsAccentOrange) {
                        AnyView(AppStoreView())
                    },
                ])

                moreSection(L10n.More.sectionTools, items: [
                    MoreItem(icon: AppIcon.udid, title: NSLocalizedString("more.udid", comment: ""), subtitle: NSLocalizedString("more.udid.sub", comment: ""), color: .dsAccent) {
                        AnyView(GetUDIDView())
                    },
                    MoreItem(icon: AppIcon.health, title: NSLocalizedString("more.healthCheck", comment: ""), subtitle: NSLocalizedString("more.healthCheck.sub", comment: ""), color: .dsAccentOrange) {
                        AnyView(HealthCheckView())
                    },
                    MoreItem(icon: AppIcon.shield, title: "证书检查", subtitle: "验证 P12 证书和描述文件有效性", color: .dsAccentCyan) {
                        AnyView(CertCheckView())
                    },
                ])

                moreSection("", items: [
                    MoreItem(icon: AppIcon.settings, title: NSLocalizedString("more.settings", comment: ""), subtitle: NSLocalizedString("more.settings.sub", comment: ""), color: .dsMuted) {
                        AnyView(SettingsView())
                    },
                ])
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle(L10n.More.title)
    }

    private func moreSection(_ title: String, items: [MoreItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                sectionHeader(title)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.title) { index, item in
                    NavigationLink { item.destination() } label: {
                        HStack(spacing: 14) {
                            HIcon(item.icon)
                                .font(.body)
                                .foregroundStyle(item.color)
                                .frame(width: 36, height: 36)
                                .background(item.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.dsText)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.dsMuted)
                            }

                            Spacer()

                            HIcon(AppIcon.chevronRight)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.dsMuted.opacity(0.4))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .glassCard(cornerRadius: 14)
        }
    }
}

private struct MoreItem {
    let icon: UIImage
    let title: String
    let subtitle: String
    let color: Color
    let destination: () -> AnyView
}
