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
            VStack(spacing: DS.spacingXL) {
                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    DSSectionHeader(L10n.More.sectionResources)
                    DSGroupedCard {
                        NavigationLink { ProfileListView() } label: {
                            DSRow(icon: AppIcon.profile, iconColor: .dsOrange, title: NSLocalizedString("more.profiles", comment: ""), subtitle: NSLocalizedString("more.profiles.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                        DSDivider()
                        NavigationLink { BundleIDListView() } label: {
                            DSRow(icon: AppIcon.bundleID, iconColor: .dsCyan, title: NSLocalizedString("more.bundleId", comment: ""), subtitle: NSLocalizedString("more.bundleId.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                        DSDivider()
                        NavigationLink { CapabilityView() } label: {
                            DSRow(icon: AppIcon.capability, iconColor: .dsPurple, title: NSLocalizedString("more.capabilities", comment: ""), subtitle: NSLocalizedString("more.capabilities.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    DSSectionHeader(L10n.More.sectionPush)
                    DSGroupedCard {
                        NavigationLink { PushKeyListView() } label: {
                            DSRow(icon: AppIcon.pushKey, iconColor: .dsPink, title: NSLocalizedString("more.pushKeys", comment: ""), subtitle: NSLocalizedString("more.pushKeys.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                        DSDivider()
                        NavigationLink { PushTestView() } label: {
                            DSRow(icon: AppIcon.pushTest, iconColor: .dsBlue, title: NSLocalizedString("more.pushTest", comment: ""), subtitle: NSLocalizedString("more.pushTest.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                        DSDivider()
                        NavigationLink { PushGuideView() } label: {
                            DSRow(icon: AppIcon.info, iconColor: .dsCyan, title: NSLocalizedString("more.pushGuide", comment: ""), subtitle: NSLocalizedString("more.pushGuide.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: DS.spacingSM) {
                    DSSectionHeader(L10n.More.sectionTools)
                    DSGroupedCard {
                        NavigationLink { GetUDIDView() } label: {
                            DSRow(icon: AppIcon.udid, iconColor: .dsGreen, title: NSLocalizedString("more.udid", comment: ""), subtitle: NSLocalizedString("more.udid.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                        DSDivider()
                        NavigationLink { HealthCheckView() } label: {
                            DSRow(icon: AppIcon.health, iconColor: .dsOrange, title: NSLocalizedString("more.healthCheck", comment: ""), subtitle: NSLocalizedString("more.healthCheck.sub", comment: ""), useGradientIcon: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                DSGroupedCard {
                    NavigationLink { SettingsView() } label: {
                        DSRow(icon: AppIcon.settings, iconColor: .dsTextSecondary, title: NSLocalizedString("more.settings", comment: ""), subtitle: NSLocalizedString("more.settings.sub", comment: ""), useGradientIcon: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacingXL)
        }
        .pageBackground()
        .navigationTitle(L10n.More.title)
    }
}
