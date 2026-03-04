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
                    VStack(spacing: 20) {
                        certInfoCard(cert)
                        downloadActions(cert)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
        .navigationTitle("证书详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadDetail(id: certId) }
        .sheet(isPresented: $downloadService.showShareSheet) {
            if let url = downloadService.downloadedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func certInfoCard(_ cert: Certificate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HIcon(AppIcon.certificate)
                    .font(.title2)
                    .foregroundStyle(cert.isExpired ? Color.dsAccentPink : Color.dsAccentPurple)
                    .frame(width: 48, height: 48)
                    .background(
                        (cert.isExpired ? Color.dsAccentPink : Color.dsAccentPurple).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(cert.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(Color.dsText)
                    HStack(spacing: 8) {
                        if cert.canDownloadP12 {
                            StatusBadge("P12", color: .dsAccentBlue)
                        }
                        if cert.isExpired {
                            StatusBadge("已过期", color: .dsAccentPink)
                        } else {
                            StatusBadge("有效", color: .dsAccent)
                        }
                    }
                }
            }

            Divider().overlay(Color.dsBorder)

            Group {
                CertDetailRow(label: "类型", value: cert.type ?? "N/A")
                if let platform = cert.platform {
                    CertDetailRow(label: "平台", value: platform)
                }
                if let serial = cert.serial_number {
                    CertDetailRow(label: "序列号", value: serial, mono: true)
                }
                if let expires = cert.expires_at {
                    CertDetailRow(label: "过期时间", value: String(expires.prefix(19)))
                }
                if let created = cert.created_at {
                    CertDetailRow(label: "创建时间", value: String(created.prefix(19)))
                }
                if let password = cert.password {
                    CertDetailRow(label: "P12 密码", value: password, mono: true, copiable: true)
                }
            }
        }
        .cardStyle()
    }

    private func downloadActions(_ cert: Certificate) -> some View {
        VStack(spacing: 10) {
            if cert.canDownloadP12 {
                Button {
                    Task { await downloadService.download(endpoint: "/certificates/\(certId)/download") }
                } label: {
                    HStack(spacing: 8) {
                        if downloadService.isDownloading {
                            ProgressView().tint(.white)
                        } else {
                            HIcon(AppIcon.docDownload).font(.body)
                        }
                        Text("下载 P12 证书")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(downloadService.isDownloading)
            }

            Button {
                Task { await downloadService.download(endpoint: "/certificates/\(certId)/download-cer") }
            } label: {
                HStack(spacing: 8) {
                    HIcon(AppIcon.docDownload).font(.body)
                    Text("下载 CER 证书")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.dsAccentOrange)
                .background(Color.dsAccentOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dsAccentOrange.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(downloadService.isDownloading)

            if let err = downloadService.errorMessage {
                Text(err).font(.caption).foregroundStyle(Color.dsAccentPink)
            }
        }
    }
}

// MARK: - Detail Row

private struct CertDetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false
    var copiable: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
                .frame(width: 80, alignment: .leading)
            Spacer()
            HStack(spacing: 6) {
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
                            .foregroundStyle(Color.dsMuted)
                    }
                }
            }
        }
    }
}
