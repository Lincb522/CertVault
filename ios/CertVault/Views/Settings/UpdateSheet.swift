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
                    VStack(spacing: 20) {
                        Spacer().frame(height: 8)

                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.dsAccentBlue, .dsAccentPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                            HIcon(AppIcon.download)
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 8) {
                            Text(NSLocalizedString("update.title", comment: ""))
                                .font(.title2.bold())
                                .foregroundStyle(Color.dsText)

                            if let info = updateService.latestVersion {
                                Text("v\(info.version) (Build \(info.build ?? "1"))")
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(Color.dsMuted)
                            }

                            Text(NSLocalizedString("update.currentVersion", comment: "") + " v\(updateService.currentVersion) (\(updateService.currentBuild))")
                                .font(.caption)
                                .foregroundStyle(Color.dsMuted)
                        }

                        if let changelog = updateService.latestVersion?.changelog, !changelog.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("update.changelog", comment: ""))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.dsText)
                                Text(changelog)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.dsMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dsBorder, lineWidth: 1))
                            .padding(.horizontal, 24)
                        }

                    }
                }

                VStack(spacing: 12) {
                    if updateService.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView(value: updateService.downloadProgress)
                                .tint(.dsAccent)
                            Text("\(Int(updateService.downloadProgress * 100))%")
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.dsMuted)
                        }
                        .padding(.horizontal, 24)
                    } else if let url = downloadedURL {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body)
                                Text("分享安装")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Color.dsAccent, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 24)
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
                            HStack(spacing: 8) {
                                HIcon(AppIcon.download)
                                    .font(.body)
                                Text("下载 IPA")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Color.dsAccent, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 24)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.dsAccentPink)
                    }

                    HStack(spacing: 16) {
                        Button {
                            guard let urlStr = downloadURLString, let url = URL(string: urlStr) else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "safari").font(.caption)
                                Text("浏览器打开").font(.subheadline)
                            }
                            .foregroundStyle(Color.dsAccent)
                        }

                        Button {
                            guard let urlStr = downloadURLString else { return }
                            UIPasteboard.general.string = urlStr
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption)
                                Text(copied ? "已复制" : "复制链接").font(.subheadline)
                            }
                            .foregroundStyle(Color.dsAccent)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("update.later", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(Color.dsMuted)
                    }
                }
                .padding(.bottom, 24)
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
