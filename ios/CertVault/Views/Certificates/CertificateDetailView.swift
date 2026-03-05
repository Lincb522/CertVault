import SwiftUI
import HiconIcons

struct CertificateDetailView: View {
    let certId: String
    var accountId: String = ""
    @StateObject private var vm = CertificateViewModel()
    @ObservedObject private var downloadService = FileDownloadService.shared

    var body: some View {
        Group {
            if let cert = vm.selectedCert {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        certInfoCard(cert)
                        downloadActions(cert)
                    }
                    .padding(.horizontal, DS.spacingLG)
                    .padding(.bottom, DS.spacing2XL)
                }
                .pageBackground()
                .refreshable { await vm.loadDetail(id: certId) }
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

    private func certInfoCard(_ cert: Certificate) -> some View {
        DSGroupedCard {
            VStack(spacing: 0) {
                HStack(spacing: DS.spacingMD) {
                    HIcon(AppIcon.certificate)
                        .font(.title2)
                        .foregroundStyle(cert.isExpired ? Color.dsPink : Color.dsPurple)
                        .frame(width: 48, height: 48)
                        .background(
                            (cert.isExpired ? Color.dsPink : Color.dsPurple).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: DS.radiusMD)
                        )

                    VStack(alignment: .leading, spacing: DS.spacingSM) {
                        Text(cert.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(Color.dsText)
                        HStack(spacing: DS.spacingSM) {
                            if cert.canDownloadP12 {
                                DSBadge(text: "P12", color: .dsBlue)
                            }
                            if cert.isExpired {
                                StatusBadge.forStatus("EXPIRED")
                            } else {
                                StatusBadge.forStatus("VALID")
                            }
                        }
                    }
                    Spacer()
                }
                .padding(DS.spacingLG)

                DSDivider(leadingPadding: 0)

                VStack(spacing: 0) {
                    CertInfoRow(label: L10n.Cert.typeLabel, value: Localized.certType(cert.type ?? L10n.na))
                    if let platform = cert.platform {
                        DSDivider(leadingPadding: 0)
                        CertInfoRow(label: L10n.Cert.platform, value: Localized.platform(platform))
                    }
                    if let serial = cert.serial_number {
                        DSDivider(leadingPadding: 0)
                        CertInfoRow(label: L10n.Cert.serial, value: serial, mono: true)
                    }
                    if let expires = cert.expires_at {
                        DSDivider(leadingPadding: 0)
                        CertInfoRow(label: L10n.Cert.expiresAt, value: String(expires.prefix(19)))
                    }
                    if let created = cert.created_at {
                        DSDivider(leadingPadding: 0)
                        CertInfoRow(label: L10n.Cert.createdAt, value: String(created.prefix(19)))
                    }
                    if let password = cert.password {
                        DSDivider(leadingPadding: 0)
                        CertInfoRow(label: L10n.Cert.password, value: password, mono: true, copiable: true)
                    }
                }
            }
        }
    }

    private func downloadActions(_ cert: Certificate) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingMD) {
            DSSectionHeader(L10n.download)

            VStack(spacing: DS.spacingMD) {
                if cert.canDownloadP12 {
                    Button {
                        Task { await downloadService.download(endpoint: "/certificates/\(certId)/download") }
                    } label: {
                        HStack(spacing: DS.spacingSM) {
                            if downloadService.isDownloading {
                                ProgressView().tint(.white)
                            } else {
                                HIcon(AppIcon.docDownload).font(.callout)
                            }
                            Text(L10n.Cert.downloadP12)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
                    }
                    .buttonStyle(.dsPressed)
                    .disabled(downloadService.isDownloading)
                }

                Button {
                    Task { await downloadService.download(endpoint: "/certificates/\(certId)/download-cer") }
                } label: {
                    HStack(spacing: DS.spacingSM) {
                        HIcon(AppIcon.docDownload).font(.callout)
                        Text(L10n.Cert.downloadCER)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(Color.dsOrange)
                    .background(Color.dsOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusMD))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radiusMD)
                            .stroke(Color.dsOrange.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.dsPressed)
                .disabled(downloadService.isDownloading)

                if let err = downloadService.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color.dsDanger)
                }
            }
        }
        .padding(DS.spacingLG)
        .cardStyle()
    }
}

// MARK: - Info Row

private struct CertInfoRow: View {
    let label: String
    let value: String
    var mono: Bool = false
    var copiable: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: 80, alignment: .leading)
            Spacer()
            HStack(spacing: DS.spacingSM) {
                Text(value)
                    .font(mono ? .subheadline.monospaced() : .subheadline)
                    .foregroundStyle(Color.dsText)
                    .textSelection(.enabled)
                if copiable {
                    Button {
                        UIPasteboard.general.string = value
                    } label: {
                        HIcon(AppIcon.copy)
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
            }
        }
        .padding(.vertical, DS.spacingMD)
        .padding(.horizontal, DS.spacingLG)
    }
}
