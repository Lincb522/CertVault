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
                } else if vm.isLoading {
                    LoadingView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let err = vm.errorMessage {
                    ErrorView(message: err) { Task { await vm.load() } }
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LoadingView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(.horizontal, 16)
        }
        .pageBackground()
        .navigationTitle("CertVault")
        .refreshable { await vm.load() }
        .onAppear {
            AppLogger.ui.info("🖼️ DashboardView appeared")
            vm.startObserving()
            vm.loadCached()
            if vm.stats != nil {
                withAnimation(.easeOut(duration: 0.3)) { animateCards = true }
            }
        }
        .task {
            await loadAllData()
        }
        .onChange(of: vm.needsRefresh) { refresh in
            if refresh {
                vm.needsRefresh = false
                animateCards = false
                Task { await loadAllData() }
            }
        }
        .sheet(isPresented: $showCreateCert) { CreateCertView(vm: certVM) }
        .sheet(isPresented: $showRegisterDevice) { RegisterDeviceSheet(vm: deviceVM) }
        .sheet(isPresented: $showCreateProfile) { CreateProfileSheetWrapper() }
    }

    private func loadAllData() async {
        async let dashboard: () = vm.load()
        async let certs: () = certVM.loadAccounts()
        async let devices: () = deviceVM.loadAccounts()
        _ = await (dashboard, certs, devices)
        if !animateCards {
            withAnimation(.easeOut(duration: 0.4)) { animateCards = true }
        }
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
        case 6..<12: return L10n.Dashboard.greetingMorning
        case 12..<14: return L10n.Dashboard.greetingNoon
        case 14..<18: return L10n.Dashboard.greetingAfternoon
        default: return L10n.Dashboard.greetingEvening
        }
    }

    // MARK: - Stats Strip

    private func statsStrip(_ stats: DashboardStats) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 2), spacing: 10) {
            MiniStatCard(title: L10n.Dashboard.statAccounts, value: stats.accounts, icon: AppIcon.account, color: .dsAccentBlue)
            MiniStatCard(title: L10n.Dashboard.statDevices, value: stats.devices, icon: AppIcon.device, color: .dsAccent)
            MiniStatCard(title: L10n.Dashboard.statCerts, value: stats.certificates, icon: AppIcon.certificate, color: .dsAccentPurple)
            MiniStatCard(title: L10n.Dashboard.statProfiles, value: stats.profiles, icon: AppIcon.profile, color: .dsAccentOrange)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.Dashboard.quickActions)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ActionChip(icon: AppIcon.addCircle, title: L10n.Dashboard.actionCreateCert, color: .dsAccentBlue) { showCreateCert = true }
                    ActionChip(icon: AppIcon.addSquare, title: L10n.Dashboard.actionAddDevice, color: .dsAccent) { showRegisterDevice = true }
                    ActionChip(icon: AppIcon.docAdd, title: L10n.Dashboard.actionProfiles, color: .dsAccentOrange) { showCreateProfile = true }
                    NavigationLink { AccountListView() } label: {
                        ActionChipLabel(icon: AppIcon.account, title: L10n.Dashboard.actionAccounts, color: .dsAccentPurple)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Recent Certificates

    private var recentCertificatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.Dashboard.recentCerts)

            if vm.recentCerts.isEmpty {
                emptyPlaceholder(icon: AppIcon.certificate, text: L10n.Dashboard.noCerts)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recentCerts.prefix(5).enumerated()), id: \.element.id) { index, cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id)
                        } label: {
                            recentRow(
                                icon: AppIcon.certificate,
                                color: .dsAccentPurple,
                                title: cert.name ?? L10n.unnamed,
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
            sectionTitle(L10n.Dashboard.recentDevices)

            if vm.recentDevices.isEmpty {
                emptyPlaceholder(icon: AppIcon.device, text: L10n.Dashboard.noDevices)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.recentDevices.prefix(5).enumerated()), id: \.element.id) { index, device in
                        recentRow(
                            icon: AppIcon.device,
                            color: .dsAccent,
                            title: device.name ?? L10n.unnamed,
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
        Localized.certType(type ?? "")
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
