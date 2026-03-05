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
            await authVM.checkAuth()
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        tabContent
            .tint(Color.dsBrand)
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
    @State private var animateIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacingXL) {
                moreSection(L10n.More.sectionResources, items: [
                    MoreItem(icon: AppIcon.profile, title: NSLocalizedString("more.profiles", comment: ""), subtitle: NSLocalizedString("more.profiles.sub", comment: ""), color: .dsOrange) {
                        AnyView(ProfileListView())
                    },
                    MoreItem(icon: AppIcon.bundleID, title: NSLocalizedString("more.bundleId", comment: ""), subtitle: NSLocalizedString("more.bundleId.sub", comment: ""), color: .dsCyan) {
                        AnyView(BundleIDListView())
                    },
                    MoreItem(icon: AppIcon.capability, title: NSLocalizedString("more.capabilities", comment: ""), subtitle: NSLocalizedString("more.capabilities.sub", comment: ""), color: .dsPurple) {
                        AnyView(CapabilityView())
                    },
                ])

                moreSection(L10n.More.sectionPush, items: [
                    MoreItem(icon: AppIcon.pushKey, title: NSLocalizedString("more.pushKeys", comment: ""), subtitle: NSLocalizedString("more.pushKeys.sub", comment: ""), color: .dsPink) {
                        AnyView(PushKeyListView())
                    },
                    MoreItem(icon: AppIcon.pushTest, title: NSLocalizedString("more.pushTest", comment: ""), subtitle: NSLocalizedString("more.pushTest.sub", comment: ""), color: .dsBlue) {
                        AnyView(PushTestView())
                    },
                    MoreItem(icon: AppIcon.info, title: NSLocalizedString("more.pushGuide", comment: ""), subtitle: NSLocalizedString("more.pushGuide.sub", comment: ""), color: .dsCyan) {
                        AnyView(PushGuideView())
                    },
                ])

                moreSection(L10n.More.sectionTools, items: [
                    MoreItem(icon: AppIcon.udid, title: NSLocalizedString("more.udid", comment: ""), subtitle: NSLocalizedString("more.udid.sub", comment: ""), color: .dsBlue) {
                        AnyView(GetUDIDView())
                    },
                    MoreItem(icon: AppIcon.health, title: NSLocalizedString("more.healthCheck", comment: ""), subtitle: NSLocalizedString("more.healthCheck.sub", comment: ""), color: .dsOrange) {
                        AnyView(HealthCheckView())
                    },
                ])

                moreSection("", items: [
                    MoreItem(icon: AppIcon.settings, title: NSLocalizedString("more.settings", comment: ""), subtitle: NSLocalizedString("more.settings.sub", comment: ""), color: .dsTextSecondary) {
                        AnyView(SettingsView())
                    },
                ])
            }
            .padding(.horizontal, DS.spacingLG)
            .padding(.bottom, DS.spacingXL)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
        }
        .pageBackground()
        .navigationTitle(L10n.More.title)
        .onAppear {
            guard !animateIn else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animateIn = true
            }
        }
    }

    private func moreSection(_ title: String, items: [MoreItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            if !title.isEmpty {
                DSSectionHeader(title)
            }

            DSGroupedCard {
                ForEach(Swift.Array(items.enumerated()), id: \.element.title) { (index: Int, item: MoreItem) in
                    NavigationLink { item.destination() } label: {
                        DSRow(icon: item.icon, iconColor: item.color, title: item.title, subtitle: item.subtitle)
                    }
                    .buttonStyle(.dsPressed)

                    if index < items.count - 1 {
                        DSDivider()
                    }
                }
            }
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
