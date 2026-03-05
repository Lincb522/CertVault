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
                        .offset(y: animateCards ? 0 : -12)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0), value: animateCards)

                    overviewCard(stats)
                        .padding(.top, DS.spacingXL)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: animateCards)

                    quickActionsSection
                        .padding(.top, DS.spacing2XL)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animateCards)

                    recentCertificatesSection
                        .padding(.top, DS.spacing2XL)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: animateCards)

                    recentDevicesSection
                        .padding(.top, DS.spacing2XL)
                        .padding(.bottom, DS.spacingXL)
                        .opacity(animateCards ? 1 : 0)
                        .offset(y: animateCards ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: animateCards)
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
            .padding(.horizontal, DS.spacingLG)
        }
        .pageBackground()
        .navigationTitle("CertVault")
        .refreshable { await vm.load() }
        .onAppear {
            vm.startObserving()
            vm.loadCached()
            if vm.stats != nil {
                withAnimation(.easeOut(duration: 0.3)) { animateCards = true }
            }
        }
        .task { await loadAllData() }
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
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD))

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title3.bold())
                    .foregroundStyle(Color.dsText)
                Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Spacer()
        }
        .padding(.top, DS.spacingSM)
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

    // MARK: - Overview Card

    private func overviewCard(_ stats: DashboardStats) -> some View {
        VStack(spacing: DS.spacingLG) {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: DS.spacingMD) {
                statItem(L10n.Dashboard.statAccounts, value: stats.accounts, icon: AppIcon.account, color: .dsBlue)
                statItem(L10n.Dashboard.statDevices, value: stats.devices, icon: AppIcon.device, color: .dsGreen, total: 100)
                statItem(L10n.Dashboard.statCerts, value: stats.certificates, icon: AppIcon.certificate, color: .dsPurple)
                statItem(L10n.Dashboard.statProfiles, value: stats.profiles, icon: AppIcon.profile, color: .dsOrange)
            }

            if stats.devices > 0 {
                VStack(spacing: DS.spacingSM) {
                    HStack {
                        Text(L10n.Dashboard.statDevices)
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                        Spacer()
                        Text("\(stats.devices) / 100")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    ProgressView(value: Double(min(stats.devices, 100)), total: 100)
                        .tint(Color.dsGreen)
                }
            }
        }
        .cardStyle()
    }

    private func statItem(_ title: String, value: Int, icon: UIImage, color: Color, total: Int? = nil) -> some View {
        HStack(spacing: DS.spacingSM) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: DS.radiusSM))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsText)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Dashboard.quickActions)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: DS.spacingSM) {
                actionCard(icon: AppIcon.addCircle, title: L10n.Dashboard.actionCreateCert, color: .dsBlue) { showCreateCert = true }
                actionCard(icon: AppIcon.addSquare, title: L10n.Dashboard.actionAddDevice, color: .dsGreen) { showRegisterDevice = true }
                actionCard(icon: AppIcon.docAdd, title: L10n.Dashboard.actionProfiles, color: .dsOrange) { showCreateProfile = true }
                NavigationLink {
                    AccountListView()
                } label: {
                    actionCardLabel(icon: AppIcon.account, title: L10n.Dashboard.actionAccounts, color: .dsPurple)
                }
                .buttonStyle(.dsPressed)
            }
        }
    }

    private func actionCard(icon: UIImage, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            actionCardLabel(icon: icon, title: title, color: color)
        }
        .buttonStyle(.dsPressed)
    }

    private func actionCardLabel(icon: UIImage, title: String, color: Color) -> some View {
        HStack(spacing: DS.spacingSM) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: DS.radiusSM))
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.dsText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(DS.spacingMD)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusMD))
        .overlay(RoundedRectangle(cornerRadius: DS.radiusMD).stroke(Color.dsBorder, lineWidth: 1))
    }

    // MARK: - Recent Certificates

    private var recentCertificatesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Dashboard.recentCerts)

            if vm.recentCerts.isEmpty {
                DSEmptyState(icon: AppIcon.certificate, title: L10n.Dashboard.noCerts)
                    .cardStyle()
            } else {
                DSGroupedCard {
                    ForEach(vm.recentCerts.prefix(5)) { cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id)
                        } label: {
                            recentRow(
                                icon: AppIcon.certificate, color: .dsPurple,
                                title: cert.name ?? L10n.unnamed,
                                subtitle: Localized.certType(cert.type ?? ""),
                                trailing: cert.created_at?.prefix(10).description
                            )
                        }
                        .buttonStyle(.dsPressed)

                        if cert.id != vm.recentCerts.prefix(5).last?.id {
                            DSDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Devices

    private var recentDevicesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Dashboard.recentDevices)

            if vm.recentDevices.isEmpty {
                DSEmptyState(icon: AppIcon.device, title: L10n.Dashboard.noDevices)
                    .cardStyle()
            } else {
                DSGroupedCard {
                    ForEach(vm.recentDevices.prefix(5)) { device in
                        recentRow(
                            icon: AppIcon.device, color: .dsGreen,
                            title: device.name ?? L10n.unnamed,
                            subtitle: (device.udid ?? "").truncated(16),
                            trailing: device.platform
                        )

                        if device.id != vm.recentDevices.prefix(5).last?.id {
                            DSDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared Row

    private func recentRow(icon: UIImage, color: Color, title: String, subtitle: String?, trailing: String?) -> some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.dsMonoSmall)
                    .foregroundStyle(Color.dsTextTertiary)
            }
        }
        .padding(.vertical, DS.spacingSM)
        .padding(.horizontal, DS.spacingLG)
        .contentShape(Rectangle())
    }
}

// MARK: - Wrapper

private struct CreateProfileSheetWrapper: View {
    @StateObject private var vm = ProfileViewModel()
    var body: some View { CreateProfileView(vm: vm) }
}
