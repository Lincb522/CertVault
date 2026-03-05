import SwiftUI
import HiconIcons

struct UpdateSheet: View {
    @EnvironmentObject private var updateService: UpdateService
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var downloadedURL: URL?
    @State private var showShareSheet = false
    @State private var errorMsg: String?

    private var downloadURLString: String? {
        guard let urlStr = updateService.latestVersion?.download_url else { return nil }
        if urlStr.hasPrefix("http") { return urlStr }
        return AppConstants.serverURL.trimmingCharacters(in: .init(charactersIn: "/")) + urlStr
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DS.spacingXL) {
                        Spacer().frame(height: DS.spacingSM)

                        ZStack {
                            Circle()
                                .fill(Color.dsBrandGradient)
                                .frame(width: 80, height: 80)
                            HIcon(AppIcon.download)
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: DS.spacingSM) {
                            Text(NSLocalizedString("update.title", comment: ""))
                                .font(.title2.bold())
                                .foregroundStyle(Color.dsText)

                            if let info = updateService.latestVersion {
                                Text("v\(info.version) (Build \(info.build ?? "1"))")
                                    .font(.dsMono)
                                    .foregroundStyle(Color.dsTextSecondary)
                            }

                            Text(NSLocalizedString("update.currentVersion", comment: "") + " v\(updateService.currentVersion) (\(updateService.currentBuild))")
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }

                        if let changelog = updateService.latestVersion?.changelog, !changelog.isEmpty {
                            DSGroupedCard {
                                VStack(alignment: .leading, spacing: DS.spacingSM) {
                                    Text(NSLocalizedString("update.changelog", comment: ""))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.dsText)
                                    Text(changelog)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.dsTextSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(DS.spacingLG)
                            }
                            .padding(.horizontal, DS.spacing2XL)
                        }
                    }
                }

                VStack(spacing: DS.spacingMD) {
                    if updateService.isDownloading {
                        VStack(spacing: DS.spacingSM) {
                            ProgressView(value: updateService.downloadProgress)
                                .tint(Color.dsBrand)
                            Text("\(Int(updateService.downloadProgress * 100))%")
                                .font(.dsMonoSmall)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        .padding(.horizontal, DS.spacing2XL)
                    } else if let url = downloadedURL {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: DS.spacingSM) {
                                Image(systemName: "square.and.arrow.up").font(.body)
                                Text("分享安装").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Color.dsGradientGreen, in: RoundedRectangle(cornerRadius: DS.radiusMD))
                        }
                        .padding(.horizontal, DS.spacing2XL)
                        .sheet(isPresented: $showShareSheet) {
                            ShareSheet(items: [url])
                        }
                    } else {
                        Button {
                            errorMsg = nil
                            Task {
                                if let url = await updateService.downloadIPA() {
                                    downloadedURL = url
                                } else {
                                    errorMsg = "下载失败，请检查网络"
                                }
                            }
                        } label: {
                            HStack(spacing: DS.spacingSM) {
                                HIcon(AppIcon.download).font(.body)
                                Text("下载 IPA").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
                        }
                        .padding(.horizontal, DS.spacing2XL)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsDanger)
                    }

                    HStack(spacing: DS.spacingLG) {
                        Button {
                            guard let urlStr = downloadURLString, let url = URL(string: urlStr) else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: DS.spacingXS) {
                                Image(systemName: "safari").font(.caption)
                                Text("浏览器打开").font(.subheadline)
                            }
                            .foregroundStyle(Color.dsBrand)
                        }

                        Button {
                            guard let urlStr = downloadURLString else { return }
                            UIPasteboard.general.string = urlStr
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            HStack(spacing: DS.spacingXS) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption)
                                Text(copied ? "已复制" : "复制链接").font(.subheadline)
                            }
                            .foregroundStyle(Color.dsBrand)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("update.later", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                .padding(.bottom, DS.spacing2XL)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        HIcon(AppIcon.close).font(.body)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
