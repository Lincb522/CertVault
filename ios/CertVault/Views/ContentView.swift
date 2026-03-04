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
            let tabNames = ["仪表盘", "账号", "设备", "证书", "更多"]
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
                    Label { Text("仪表盘") } icon: { HIcon(AppIcon.dashboard) }
                }
                Tab(value: 1) {
                    NavigationStack { AccountListView() }
                } label: {
                    Label { Text("账号") } icon: { HIcon(AppIcon.account) }
                }
                Tab(value: 2) {
                    NavigationStack { DeviceListView() }
                } label: {
                    Label { Text("设备") } icon: { HIcon(AppIcon.device) }
                }
                Tab(value: 3) {
                    NavigationStack { CertificateListView() }
                } label: {
                    Label { Text("证书") } icon: { HIcon(AppIcon.certificate) }
                }
                Tab(value: 4) {
                    NavigationStack { MoreView() }
                } label: {
                    Label { Text("更多") } icon: { HIcon(AppIcon.more) }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack { DashboardView() }
                    .tabItem { Label { Text("仪表盘") } icon: { HIcon(AppIcon.dashboard) } }
                    .tag(0)
                NavigationStack { AccountListView() }
                    .tabItem { Label { Text("账号") } icon: { HIcon(AppIcon.account) } }
                    .tag(1)
                NavigationStack { DeviceListView() }
                    .tabItem { Label { Text("设备") } icon: { HIcon(AppIcon.device) } }
                    .tag(2)
                NavigationStack { CertificateListView() }
                    .tabItem { Label { Text("证书") } icon: { HIcon(AppIcon.certificate) } }
                    .tag(3)
                NavigationStack { MoreView() }
                    .tabItem { Label { Text("更多") } icon: { HIcon(AppIcon.more) } }
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
                moreSection("资源管理", items: [
                    MoreItem(icon: AppIcon.profile, title: "描述文件", subtitle: "管理 Provisioning Profiles", color: .dsAccentOrange) {
                        AnyView(ProfileListView())
                    },
                    MoreItem(icon: AppIcon.bundleID, title: "Bundle ID", subtitle: "管理应用标识符", color: .dsAccentCyan) {
                        AnyView(BundleIDListView())
                    },
                    MoreItem(icon: AppIcon.capability, title: "权限管理", subtitle: "配置 App Capabilities", color: .dsAccentPurple) {
                        AnyView(CapabilityView())
                    },
                ])

                moreSection("推送服务", items: [
                    MoreItem(icon: AppIcon.pushKey, title: "推送密钥", subtitle: "APNs Key 管理", color: .dsAccentPink) {
                        AnyView(PushKeyListView())
                    },
                    MoreItem(icon: AppIcon.pushTest, title: "推送测试", subtitle: "发送测试推送通知", color: .dsAccentBlue) {
                        AnyView(PushTestView())
                    },
                    MoreItem(icon: AppIcon.info, title: "推送指南", subtitle: "配置方式与错误码参考", color: .dsAccentCyan) {
                        AnyView(PushGuideView())
                    },
                ])

                moreSection("工具", items: [
                    MoreItem(icon: AppIcon.udid, title: "获取 UDID", subtitle: "通过 Safari 获取设备 UDID", color: .dsAccent) {
                        AnyView(GetUDIDView())
                    },
                    MoreItem(icon: AppIcon.health, title: "健康检查", subtitle: "检测 API 连接和配置", color: .dsAccentOrange) {
                        AnyView(HealthCheckView())
                    },
                ])

                moreSection("", items: [
                    MoreItem(icon: AppIcon.settings, title: "设置", subtitle: "账户与服务器配置", color: .dsMuted) {
                        AnyView(SettingsView())
                    },
                ])
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .pageBackground()
        .navigationTitle("更多")
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
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
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
