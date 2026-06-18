import Foundation
import os.log

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.certmanager.app"

    static let api = Logger(subsystem: subsystem, category: "API")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let data = Logger(subsystem: subsystem, category: "Data")

    static func logRequest(_ method: String, endpoint: String, body: (any Encodable)? = nil) {
        var msg = "➡️ \(method) \(endpoint)"
        if let body = body, let json = try? JSONEncoder().encode(body), let str = String(data: json, encoding: .utf8) {
            let truncated = str.count > 500 ? String(str.prefix(500)) + "..." : str
            msg += " | Body: \(truncated)"
        }
        api.info("\(msg)")
    }

    static func logResponse(_ method: String, endpoint: String, status: Int, data: Data, duration: TimeInterval) {
        let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .memory)
        let ms = String(format: "%.0f", duration * 1000)
        let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<binary>"
        let truncated = preview.count > 800 ? String(preview.prefix(800)) + "..." : preview

        if (200...299).contains(status) {
            api.info("✅ \(method) \(endpoint) → \(status) [\(ms)ms, \(size)] \(truncated)")
        } else {
            api.error("❌ \(method) \(endpoint) → \(status) [\(ms)ms, \(size)] \(truncated)")
        }
    }

    static func logError(_ method: String, endpoint: String, error: Error, duration: TimeInterval) {
        let ms = String(format: "%.0f", duration * 1000)
        api.error("💥 \(method) \(endpoint) FAILED [\(ms)ms] \(error.localizedDescription)")
    }

    static func logDownload(_ endpoint: String, status: Int, filename: String?, size: Int64) {
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .memory)
        api.info("📥 DOWNLOAD \(endpoint) → \(status) file=\(filename ?? "unknown") size=\(sizeStr)")
    }

    static func logUpload(_ endpoint: String, fileName: String, size: Int) {
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory)
        api.info("📤 UPLOAD \(endpoint) file=\(fileName) size=\(sizeStr)")
    }
}
