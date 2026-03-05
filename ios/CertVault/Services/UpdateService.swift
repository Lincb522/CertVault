import Foundation
import SwiftUI

struct AppVersionInfo: Codable {
    let version: String
    let build: String?
    let changelog: String?
    let force_update: Bool?
    let download_url: String?
    let updated_at: String?
}

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    @Published var latestVersion: AppVersionInfo?
    @Published var updateAvailable = false
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var lastError: String?

    private let api = APIClient.shared

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    func checkForUpdate() async {
        isChecking = true
        lastError = nil
        defer { isChecking = false }

        do {
            let resp: APIResponse<AppVersionInfo> = try await api.request("/app/version", method: "GET")
            guard let info = resp.data else {
                latestVersion = nil
                updateAvailable = false
                lastError = "服务器未返回版本信息"
                return
            }
            latestVersion = info
            updateAvailable = isNewer(
                remoteVersion: info.version, remoteBuild: info.build ?? "1",
                localVersion: currentVersion, localBuild: currentBuild
            )
        } catch {
            latestVersion = nil
            updateAvailable = false
            lastError = error.localizedDescription
            AppLogger.api.error("Update check failed: \(error.localizedDescription)")
        }
    }

    func downloadIPA() async -> URL? {
        guard let info = latestVersion, let urlStr = info.download_url else { return nil }

        let fullURL: String
        if urlStr.hasPrefix("http") {
            fullURL = urlStr
        } else {
            fullURL = AppConstants.serverURL.trimmingCharacters(in: .init(charactersIn: "/")) + urlStr
        }

        guard let url = URL(string: fullURL) else { return nil }

        isDownloading = true
        downloadProgress = 0
        defer { isDownloading = false }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url, delegate: nil)
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                AppLogger.api.error("Cannot locate documents directory")
                return nil
            }
            let dest = docs.appendingPathComponent("CertVault-\(info.version).ipa")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            downloadProgress = 1.0
            AppLogger.data.info("IPA downloaded to \(dest.path)")
            return dest
        } catch {
            AppLogger.api.error("IPA download failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func isNewer(remoteVersion: String, remoteBuild: String,
                         localVersion: String, localBuild: String) -> Bool {
        let r = remoteVersion.split(separator: ".").compactMap { Int($0) }
        let l = localVersion.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        let rb = Int(remoteBuild) ?? 0
        let lb = Int(localBuild) ?? 0
        return rb > lb
    }
}
