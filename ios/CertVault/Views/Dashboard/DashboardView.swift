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
                        .staggeredAppear(index: 0, animate: animateCards)

                    statsGrid(stats)
                        .padding(.top, DS.spacingXL)
                        .staggeredAppear(index: 1, animate: animateCards)

                    quickActionsSection
                        .padding(.top, DS.spacing2XL)
                        .staggeredAppear(index: 2, animate: animateCards)

                    recentCertificatesSection
                        .padding(.top, DS.spacing2XL)
                        .staggeredAppear(index: 3, animate: animateCards)

                    recentDevicesSection
                        .padding(.top, DS.spacing2XL)
                        .padding(.bottom, DS.spacingXL)
                        .staggeredAppear(index: 4, animate: animateCards)
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
        DSGradientCard(gradient: .dsGradientBlue) {
            HStack(spacing: DS.spacingMD) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(stats.accounts)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(L10n.Dashboard.statAccounts)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
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

    // MARK: - Stats Grid

    private func statsGrid(_ stats: DashboardStats) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: DS.spacingMD), count: 2), spacing: DS.spacingMD) {
            DSStatCard(
                title: L10n.Dashboard.statDevices,
                value: "\(stats.devices)",
                icon: AppIcon.device,
                gradient: .dsGradientGreen
            )
            DSStatCard(
                title: L10n.Dashboard.statCerts,
                value: "\(stats.certificates)",
                icon: AppIcon.certificate,
                gradient: .dsGradientPurple
            )
            DSStatCard(
                title: L10n.Dashboard.statProfiles,
                value: "\(stats.profiles)",
                icon: AppIcon.profile,
                gradient: .dsGradientOrange
            )
            DSStatCard(
                title: L10n.Dashboard.statAccounts,
                value: "\(stats.accounts)",
                icon: AppIcon.account,
                gradient: .dsGradientCyan
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Dashboard.quickActions)

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: DS.spacingMD), count: 3), spacing: DS.spacingMD) {
                DSActionCard(
                    title: L10n.Dashboard.actionCreateCert,
                    icon: AppIcon.addCircle,
                    gradient: .dsGradientPurple
                ) { showCreateCert = true }

                DSActionCard(
                    title: L10n.Dashboard.actionAddDevice,
                    icon: AppIcon.addSquare,
                    gradient: .dsGradientGreen
                ) { showRegisterDevice = true }

                DSActionCard(
                    title: L10n.Dashboard.actionProfiles,
                    icon: AppIcon.docAdd,
                    gradient: .dsGradientOrange
                ) { showCreateProfile = true }
            }
        }
    }

    // MARK: - Recent Certificates

    private var recentCertificatesSection: some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.Dashboard.recentCerts) {
                DSBadge(text: L10n.count(vm.recentCerts.count), color: .dsTextSecondary)
            }

            if vm.recentCerts.isEmpty {
                DSGroupedCard {
                    DSEmptyState(icon: AppIcon.certificate, title: L10n.Dashboard.noCerts)
                }
            } else {
                DSGroupedCard {
                    ForEach(Array(vm.recentCerts.prefix(5).enumerated()), id: \.element.id) { index, cert in
                        NavigationLink {
                            CertificateDetailView(certId: cert.id)
                        } label: {
                            DSRow(
                                icon: AppIcon.certificate,
                                iconColor: .dsPurple,
                                title: cert.name ?? L10n.unnamed,
                                subtitle: certTypeLabel(cert.type),
                                trailing: cert.created_at.map {
                                    AnyView(Text(String($0.prefix(10))).font(.dsMonoSmall).foregroundStyle(Color.dsTextTertiary))
                                }
                            )
                        }
                        .buttonStyle(.dsPressed)

                        if index < min(vm.recentCerts.count, 5) - 1 {
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
            DSSectionHeader(L10n.Dashboard.recentDevices) {
                DSBadge(text: L10n.count(vm.recentDevices.count), color: .dsTextSecondary)
            }

            if vm.recentDevices.isEmpty {
                DSGroupedCard {
                    DSEmptyState(icon: AppIcon.device, title: L10n.Dashboard.noDevices)
                }
            } else {
                DSGroupedCard {
                    ForEach(Array(vm.recentDevices.prefix(5).enumerated()), id: \.element.id) { index, device in
                        DSRow(
                            icon: AppIcon.device,
                            iconColor: .dsGreen,
                            title: device.name ?? L10n.unnamed,
                            subtitle: (device.udid ?? "").truncated(16),
                            trailing: device.platform.map {
                                AnyView(Text($0).font(.caption2).foregroundStyle(Color.dsTextTertiary))
                            },
                            showChevron: false
                        )

                        if index < min(vm.recentDevices.count, 5) - 1 {
                            DSDivider()
                        }
                    }
                }
            }
        }
    }

    private func certTypeLabel(_ type: String?) -> String {
        Localized.certType(type ?? "")
    }
}

// MARK: - Wrapper

private struct CreateProfileSheetWrapper: View {
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        CreateProfileView(vm: vm)
    }
}
