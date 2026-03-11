import SwiftUI
import CoreImage.CIFilterBuiltins
import HiconIcons

struct GetUDIDView: View {
    @StateObject private var vm = UDIDViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let result = vm.udidResult {
                    resultView(result)
                } else if vm.enrollURL != nil {
                    enrollView
                } else {
                    startView
                }
            }
            .padding()
        }
        .pageBackground()
        .navigationTitle(L10n.UDID.title)
        .onDisappear { vm.stopPolling() }
    }

    private var startView: some View {
        VStack(spacing: 20) {
            HIcon(AppIcon.udid)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentGradient)

            Text(L10n.UDID.heading)
                .font(.title2.bold())
            Text(L10n.UDID.desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            GradientButton(NSLocalizedString("udid.generate", comment: ""), icon: AppIcon.link) {
                Task { await vm.createRequest() }
            }
            .padding(.horizontal, 40)
            .disabled(vm.isLoading)

            if vm.isLoading {
                ProgressView()
            }

            if let err = vm.errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.top, 40)
    }

    private var enrollView: some View {
        VStack(spacing: 20) {
            if let url = vm.enrollURL {
                Text(L10n.UDID.scanQR)
                    .font(.headline)
                Text(L10n.UDID.orVisit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let qrImage = generateQRCode(from: url) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding()
                        .glassCard(cornerRadius: 16)
                }

                VStack(spacing: 8) {
                    Text(url)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        UIPasteboard.general.string = url
                    } label: {
                        Label {
                            Text(L10n.UDID.copyLink)
                        } icon: {
                            HIcon(AppIcon.copy)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.dsAccentBlue)
                    .controlSize(.small)
                }

                if vm.isPolling {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L10n.UDID.waiting)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                Button(L10n.UDID.regenerate) {
                    vm.reset()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
        }
    }

    private func resultView(_ result: UDIDResult) -> some View {
        VStack(spacing: 20) {
            HIcon(AppIcon.check)
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text(L10n.UDID.success)
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                UDIDInfoRow(label: "UDID", value: result.udid ?? L10n.na, mono: true)
                UDIDInfoRow(label: NSLocalizedString("udid.model", comment: ""), value: result.product ?? L10n.na)
                UDIDInfoRow(label: NSLocalizedString("udid.version", comment: ""), value: result.version ?? L10n.na)
                if let name = result.device_name {
                    UDIDInfoRow(label: NSLocalizedString("udid.deviceName", comment: ""), value: name)
                }
                if let serial = result.serial {
                    UDIDInfoRow(label: L10n.Cert.serial, value: serial, mono: true)
                }
            }
            .cardStyle()

            Button {
                var text = "UDID: \(result.udid ?? "")\n"
                text += "型号: \(result.product ?? "")\n"
                text += "版本: \(result.version ?? "")"
                UIPasteboard.general.string = text
            } label: {
                Label {
                    Text(L10n.UDID.copyAll)
                } icon: {
                    HIcon(AppIcon.copy)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.dsAccentBlue)

            Button(L10n.UDID.retry) {
                vm.reset()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scale = 250 / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct UDIDInfoRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(mono ? .subheadline.monospaced() : .subheadline)
                .textSelection(.enabled)
        }
    }
}
