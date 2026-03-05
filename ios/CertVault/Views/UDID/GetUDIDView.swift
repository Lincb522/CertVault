import SwiftUI
import CoreImage.CIFilterBuiltins
import HiconIcons

struct GetUDIDView: View {
    @StateObject private var vm = UDIDViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.spacing2XL) {
                if let result = vm.udidResult {
                    resultView(result)
                } else if vm.enrollURL != nil {
                    enrollView
                } else {
                    startView
                }
            }
            .padding(DS.spacingLG)
        }
        .pageBackground()
        .navigationTitle(L10n.UDID.title)
        .onDisappear { vm.stopPolling() }
    }

    private var startView: some View {
        VStack(spacing: DS.spacingXL) {
            HIcon(AppIcon.udid)
                .font(.system(size: 64))
                .foregroundStyle(Color.dsBrandGradient)

            Text(L10n.UDID.heading)
                .font(.title2.bold())
                .foregroundStyle(Color.dsText)
            Text(L10n.UDID.desc)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)

            DSPrimaryButton(title: NSLocalizedString("udid.generate", comment: ""), isLoading: vm.isLoading) {
                Task { await vm.createRequest() }
            }
            .disabled(vm.isLoading)

            if vm.isLoading {
                ProgressView()
                    .tint(Color.dsBrand)
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Color.dsDanger)
            }
        }
        .padding(.top, DS.spacing3XL)
    }

    private var enrollView: some View {
        VStack(spacing: DS.spacingXL) {
            if let url = vm.enrollURL {
                Text(L10n.UDID.scanQR)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(L10n.UDID.orVisit)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)

                if let qrImage = generateQRCode(from: url) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(DS.spacingLG)
                        .cardStyle()
                }

                VStack(spacing: DS.spacingSM) {
                    Text(url)
                        .font(.dsMono)
                        .foregroundStyle(Color.dsTextSecondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        UIPasteboard.general.string = url
                    } label: {
                        HStack(spacing: DS.spacingSM) {
                            HIcon(AppIcon.copy)
                                .font(.callout)
                            Text(L10n.UDID.copyLink)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.spacing2XL)
                        .padding(.vertical, DS.spacingMD)
                        .background(Color.dsBrand, in: Capsule())
                    }
                    .buttonStyle(.dsPressed)
                }

                if vm.isPolling {
                    HStack(spacing: DS.spacingSM) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.dsBrand)
                        Text(L10n.UDID.waiting)
                            .font(.caption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .padding(.top, DS.spacingSM)
                }

                Button(L10n.UDID.regenerate) {
                    vm.reset()
                }
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.top, DS.spacingSM)
                .buttonStyle(.plain)
            }
        }
    }

    private func resultView(_ result: UDIDResult) -> some View {
        VStack(spacing: DS.spacingXL) {
            HIcon(AppIcon.check)
                .font(.system(size: 56))
                .foregroundStyle(Color.dsSuccess)

            Text(L10n.UDID.success)
                .font(.title2.bold())
                .foregroundStyle(Color.dsText)

            DSGroupedCard {
                UDIDInfoRow(label: "UDID", value: result.udid ?? L10n.na, mono: true)
                DSDivider(leadingPadding: 0)
                UDIDInfoRow(label: NSLocalizedString("udid.model", comment: ""), value: result.product ?? L10n.na)
                DSDivider(leadingPadding: 0)
                UDIDInfoRow(label: NSLocalizedString("udid.version", comment: ""), value: result.version ?? L10n.na)
                if let name = result.device_name {
                    DSDivider(leadingPadding: 0)
                    UDIDInfoRow(label: NSLocalizedString("udid.deviceName", comment: ""), value: name)
                }
                if let serial = result.serial {
                    DSDivider(leadingPadding: 0)
                    UDIDInfoRow(label: L10n.Cert.serial, value: serial, mono: true)
                }
            }

            Button {
                var text = "UDID: \(result.udid ?? "")\n"
                text += "型号: \(result.product ?? "")\n"
                text += "版本: \(result.version ?? "")"
                UIPasteboard.general.string = text
            } label: {
                HStack(spacing: DS.spacingSM) {
                    HIcon(AppIcon.copy)
                        .font(.callout)
                    Text(L10n.UDID.copyAll)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
            }
            .buttonStyle(.dsPressed)

            Button(L10n.UDID.retry) {
                vm.reset()
            }
            .font(.subheadline)
            .foregroundStyle(Color.dsTextSecondary)
            .buttonStyle(.plain)
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
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            Text(value)
                .font(mono ? .dsMono : .subheadline)
                .foregroundStyle(Color.dsText)
                .textSelection(.enabled)
        }
        .padding(.vertical, DS.spacingMD)
        .padding(.horizontal, DS.spacingLG)
    }
}
