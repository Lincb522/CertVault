import SwiftUI
import HiconIcons

struct CertificateDetailView: View {
    let certId: String
    var accountId: String = ""
    @StateObject private var vm = CertificateViewModel()
    @ObservedObject private var downloadService = FileDownloadService.shared
    @State private var appeared = false

    var body: some View {
        Group {
            if let cert = vm.selectedCert {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        heroHeader(cert)
                            .staggeredAppear(index: 0, animate: appeared)
                        infoSection(cert)
                            .staggeredAppear(index: 1, animate: appeared)
                        downloadActions(cert)
                            .staggeredAppear(index: 2, animate: appeared)
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacingXL)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(id: certId) }
                .onAppear { withAnimation { appeared = true } }
            } else if vm.isLoading {
                LoadingView()
            } else if let err = vm.errorMessage {
                ErrorView(message: err) { Task { await vm.loadDetail(id: certId) } }
            } else {
                LoadingView()
            }
        }
        .navigationTitle(L10n.Cert.detail)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadDetail(id: certId) }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Hero Header

    private func heroHeader(_ cert: Certificate) -> some View {
        VStack(spacing: DS.spacingMD) {
            HIcon(AppIcon.certificate)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    cert.isExpired ? Color.dsGradientPink : Color.dsGradientPurple,
                    in: RoundedRectangle(cornerRadius: DS.radiusLG)
                )

            Text(cert.displayName)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dsText)
                .multilineTextAlignment(.center)

            HStack(spacing: DS.spacingSM) {
                if cert.canDownloadP12 {
                    DSBadge(text: "P12", color: .dsBlue)
                }
                if cert.isExpired {
                    DSBadge.forStatus("EXPIRED")
                } else {
                    DSBadge.forStatus("VALID")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingXL)
    }

    // MARK: - Info

    private func infoSection(_ cert: Certificate) -> some View {
        DSGroupedCard {
            infoRow(label: L10n.Cert.typeLabel, value: Localized.certType(cert.type ?? L10n.na))
            if let platform = cert.platform {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: L10n.Cert.platform, value: Localized.platform(platform))
            }
            if let serial = cert.serial_number {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: L10n.Cert.serial, value: serial, mono: true)
            }
            if let expires = cert.expires_at {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: L10n.Cert.expiresAt, value: String(expires.prefix(19)))
            }
            if let created = cert.created_at {
                DSDivider(leadingPadding: DS.spacingLG)
                infoRow(label: L10n.Cert.createdAt, value: String(created.prefix(19)))
            }
            if let password = cert.password {
                DSDivider(leadingPadding: DS.spacingLG)
                passwordRow(label: L10n.Cert.password, value: password)
            }
        }
    }

    // MARK: - Download Actions

    private func downloadActions(_ cert: Certificate) -> some View {
        VStack(spacing: DS.spacingMD) {
            if cert.canDownloadP12 {
                DSPrimaryButton(
                    title: L10n.Cert.downloadP12,
                    isLoading: downloadService.isDownloading
                ) {
                    Task { await downloadService.download(endpoint: "/certificates/\(certId)/download") }
                }
            }

            Button {
                Task { await downloadService.download(endpoint: "/certificates/\(certId)/download-cer") }
            } label: {
                HStack(spacing: DS.spacingSM) {
                    HIcon(AppIcon.docDownload).font(.body)
                    Text(L10n.Cert.downloadCER)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.dsOrange)
                .background(Color.dsOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusMD))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusMD)
                        .stroke(Color.dsOrange.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(downloadService.isDownloading)

            if let err = downloadService.errorMessage {
                Text(err).font(.caption).foregroundStyle(Color.dsRed)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            Text(value)
                .font(mono ? .dsMono : .subheadline)
                .foregroundStyle(Color.dsText)
                .textSelection(.enabled)
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
    }

    private func passwordRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            HStack(spacing: DS.spacingSM) {
                Text(value)
                    .font(.dsMono)
                    .foregroundStyle(Color.dsText)
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    HIcon(AppIcon.copy)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, DS.spacingMD)
    }
}
