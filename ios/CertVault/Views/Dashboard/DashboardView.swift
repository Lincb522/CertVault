import SwiftUI
import HiconIcons

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel()
    @StateObject private var certVM = CertificateViewModel()
    @StateObject private var deviceVM = DeviceViewModel()
    @State private var showCreateCert = false
    @State private var showRegisterDevice = false
    @State private var showCreateProfile = false
    @State private var animateCards = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let stats = vm.stats {
                    heroSection(stats)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : -10)

                    statsStrip(stats)
                        .padding(.top, 20)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 12)

                    quickActionsSection
                        .padding(.top, 24)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 12)

                    recentCertificatesSection
                        .padding(.top, 24)
                        .opacity(animateCards ? 1 : 0)

                    recentDevicesSection
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                        .opacity(animateCards ? 1 : 0)
                }
            }
            .padding(.horizontal, 16)
        }
        .pageBackground()
        .navigationTitle("CertVault")
        .refreshable { await vm.load() }
        .overlay {
            if vm.isLoading && vm.stats == nil {
                LoadingView()
            } else if let err = vm.errorMessage, vm.stats == nil {
                ErrorView(message: err) { Task { await vm.load() } }
            }
        }
        .task {
            await vm.load()
            await certVM.loadAccounts()
            await deviceVM.loadAccounts()
            withAnimation(.easeOut(duration: 0.5)) { animateCards = true }
        }
        .onAppear { AppLogger.ui.info("🖼️ DashboardView appeared") }
        .sheet(isPresented: $showCreateCert) { CreateCertView(vm: certVM) }
        .sheet(isPresented: $showRegisterDevice) { RegisterDeviceSheet(vm: deviceVM) }
        .sheet(isPresented: $showCreateProfile) { CreateProfileSheetWrapper() }
    }

    // MARK: - Hero

    private func heroSection(_ stats: DashboardStats) -> some View {
        HStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.title3.bold())
                    .foregroundStyle(Color.dsText)
                Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 6..<12: return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    // MARK: - Stats Strip

    private func statsStrip(_ stats: DashboardStats) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 2), spacing: 10) {
            MiniStatCard(title: "开发者账号", value: stats.accounts, icon: AppIcon.account, color: .dsAccentBlue)
            MiniStatCard(title: "注册设备", value: stats.devices, icon: AppIcon.device, color: .dsAccent)
            MiniStatCard(title: "签名证书", value: stats.certificates, icon: AppIcon.certificate, color: .dsAccentPurple)
            MiniStatCard(title: "描述文件", value: stats.profiles, icon: AppIcon.profile, color: .dsAccentOrange)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("快捷操作")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ActionChip(icon: AppIcon.addCircle, title: "创建证书", color: .dsAccentBlue) { showCreateCert = true }
                    ActionChip(icon: AppIcon.addSquare, title: "添加设备", color: .dsAccent) { showRegisterDevice = true }
                    ActionChip(icon: AppIcon.docAdd, title: "描述文件", color: .dsAccentOrange) { showCreateProfile = true }
                    NavigationLink { AccountListView() } label: {
                        ActionChipLabel(icon: AppIcon.account, title: "管理账号", color: .dsAccentPurple)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Recent Certificates

    private var recentCertificatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("最近证书")

            if vm.recentCerts.isEmpty {
                emptyPlaceholder(icon: AppIcon.certificate, text: "暂无证书")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recentCerts.prefix(5).enumerated()), id: \.element.id) { index, cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id)
                        } label: {
                            recentRow(
                                icon: AppIcon.certificate,
                                color: .dsAccentPurple,
                                title: cert.name ?? "未命名",
                                subtitle: certTypeLabel(cert.type),
                                trailing: cert.created_at?.prefix(10).description
                            )
                        }
                        .buttonStyle(.plain)

                        if index < min(vm.recentCerts.count, 5) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, 4)
                .cardStyle()
            }
        }
    }

    // MARK: - Recent Devices

    private var recentDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("最近设备")

            if vm.recentDevices.isEmpty {
                emptyPlaceholder(icon: AppIcon.device, text: "暂无设备")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recentDevices.prefix(5).enumerated()), id: \.element.id) { index, device in
                        recentRow(
                            icon: AppIcon.device,
                            color: .dsAccent,
                            title: device.name ?? "未命名",
                            subtitle: (device.udid ?? "").truncated(16),
                            trailing: device.platform
                        )

                        if index < min(vm.recentDevices.count, 5) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, 4)
                .cardStyle()
            }
        }
    }

    // MARK: - Shared Components

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.dsMuted)
    }

    private func emptyPlaceholder(icon: UIImage, text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                HIcon(icon)
                    .font(.title2)
                    .foregroundStyle(Color.dsMuted.opacity(0.3))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted.opacity(0.6))
            }
            .padding(.vertical, 28)
            Spacer()
        }
        .cardStyle()
    }

    private func recentRow(icon: UIImage, color: Color, title: String, subtitle: String?, trailing: String?) -> some View {
        HStack(spacing: 12) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(color)
                .padding(8)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.dsMuted.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    private func certTypeLabel(_ type: String?) -> String {
        switch type {
        case "IOS_DEVELOPMENT": return "iOS 开发"
        case "IOS_DISTRIBUTION": return "iOS 发布"
        case "MAC_APP_DEVELOPMENT": return "macOS 开发"
        case "MAC_APP_DISTRIBUTION": return "macOS 发布"
        case "DEVELOPER_ID_APPLICATION": return "Developer ID"
        default: return type ?? ""
        }
    }
}

// MARK: - Mini Stat Card

private struct MiniStatCard: View {
    let title: String
    let value: Int
    let icon: UIImage
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            HIcon(icon)
                .font(.body)
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsText)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Action Chip

private struct ActionChip: View {
    let icon: UIImage
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionChipLabel(icon: icon, title: title, color: color)
        }
    }
}

private struct ActionChipLabel: View {
    let icon: UIImage
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(.white)
                .padding(7)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.dsText)
        }
        .padding(.trailing, 14)
        .padding(.leading, 4)
        .padding(.vertical, 4)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }
}

// MARK: - Wrapper

private struct CreateProfileSheetWrapper: View {
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        CreateProfileView(vm: vm)
    }
}
