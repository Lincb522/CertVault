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
        .navigationTitle("获取 UDID")
        .onDisappear { vm.stopPolling() }
    }

    private var startView: some View {
        VStack(spacing: 20) {
            HIcon(AppIcon.udid)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentGradient)

            Text("获取设备 UDID")
                .font(.title2.bold())
            Text("生成获取链接，在 iPhone 上访问并安装描述文件即可获取 UDID")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            GradientButton("生成获取链接", icon: AppIcon.link) {
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
                Text("请用 iPhone 扫描二维码")
                    .font(.headline)
                Text("或在 Safari 中访问以下链接")
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
                            Text("复制链接")
                        } icon: {
                            HIcon(AppIcon.copy)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if vm.isPolling {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("等待设备安装描述文件...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                Button("重新生成") {
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

            Text("获取成功！")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                UDIDInfoRow(label: "UDID", value: result.udid ?? "N/A", mono: true)
                UDIDInfoRow(label: "设备型号", value: result.product ?? "N/A")
                UDIDInfoRow(label: "系统版本", value: result.version ?? "N/A")
                if let name = result.device_name {
                    UDIDInfoRow(label: "设备名称", value: name)
                }
                if let serial = result.serial {
                    UDIDInfoRow(label: "序列号", value: serial, mono: true)
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
                    Text("复制全部信息")
                } icon: {
                    HIcon(AppIcon.copy)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("重新获取") {
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
