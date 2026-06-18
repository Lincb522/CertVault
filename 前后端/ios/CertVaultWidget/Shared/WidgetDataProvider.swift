import Foundation
import GRDB

struct AccountWidgetData: Identifiable {
    let id: String
    let name: String
    let certCount: Int
    let deviceCount: Int
    let profileCount: Int
}

struct ExpiringItem: Identifiable {
    let id: String
    let name: String
    let type: String
    let kind: ItemKind
    let expiresAt: Date
    let daysLeft: Int

    enum ItemKind: String {
        case certificate = "证书"
        case profile = "描述文件"
    }
}

final class WidgetDataProvider {
    static let shared = WidgetDataProvider()

    private var dbQueue: DatabaseQueue?

    private init() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) else { return }
        let dbPath = groupURL.appendingPathComponent("certvault.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else { return }
        dbQueue = try? DatabaseQueue(path: dbPath, configuration: {
            var config = Configuration()
            config.readonly = true
            return config
        }())
    }

    func fetchStats() -> DashboardStats? {
        guard let db = dbQueue else { return nil }
        return try? db.read { db in
            let accounts = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM accounts") ?? 0
            let devices = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM devices") ?? 0
            let certificates = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM certificates") ?? 0
            let profiles = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM profiles") ?? 0
            let bundleIds = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM bundleIds") ?? 0
            if accounts == 0 && devices == 0 && certificates == 0 { return nil }
            return DashboardStats(
                accounts: accounts, devices: devices,
                certificates: certificates, certs_with_p12: nil,
                profiles: profiles, bundle_ids: bundleIds
            )
        }
    }

    func fetchRecentCertificates(limit: Int = 3) -> [RecentCertificate] {
        guard let db = dbQueue else { return [] }
        return (try? db.read { db in
            let rows = try Row.fetchAll(db, sql:
                "SELECT id, name, type, expires_at, created_at FROM certificates ORDER BY created_at DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.map {
                RecentCertificate(id: $0["id"], name: $0["name"], type: $0["type"], expires_at: $0["expires_at"], created_at: $0["created_at"])
            }
        }) ?? []
    }

    func fetchExpiringItems(limit: Int = 5) -> [ExpiringItem] {
        guard let db = dbQueue else { return [] }
        let now = Date()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String?) -> Date? {
            guard let s = str else { return nil }
            if let d = iso.date(from: s) { return d }
            if let d = isoBasic.date(from: s) { return d }
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df.date(from: s)
        }

        var items: [ExpiringItem] = []

        if let certs = try? db.read({ db in try Row.fetchAll(db, sql: "SELECT id, name, type, expires_at FROM certificates WHERE expires_at IS NOT NULL") }) {
            for row in certs {
                guard let date = parseDate(row["expires_at"] as String?) else { continue }
                let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
                if days < 90 {
                    items.append(ExpiringItem(
                        id: row["id"], name: (row["name"] as String?) ?? "未命名证书",
                        type: (row["type"] as String?) ?? "", kind: .certificate,
                        expiresAt: date, daysLeft: max(days, 0)
                    ))
                }
            }
        }

        if let profiles = try? db.read({ db in try Row.fetchAll(db, sql: "SELECT id, name, type, expires_at FROM profiles WHERE expires_at IS NOT NULL") }) {
            for row in profiles {
                guard let date = parseDate(row["expires_at"] as String?) else { continue }
                let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
                if days < 90 {
                    items.append(ExpiringItem(
                        id: row["id"], name: (row["name"] as String?) ?? "未命名描述文件",
                        type: (row["type"] as String?) ?? "", kind: .profile,
                        expiresAt: date, daysLeft: max(days, 0)
                    ))
                }
            }
        }

        items.sort { $0.expiresAt < $1.expiresAt }
        return Array(items.prefix(limit))
    }

    func fetchAccountStatus() -> [AccountWidgetData] {
        guard let db = dbQueue else { return [] }
        return (try? db.read { db in
            let accounts = try Row.fetchAll(db, sql: "SELECT id, name FROM accounts")
            return accounts.map { row in
                let accId: String = row["id"]
                let name: String = (row["name"] as String?) ?? "未命名账号"
                let certs = (try? Int.fetchOne(db, sql: "SELECT COUNT(*) FROM certificates WHERE account_id = ?", arguments: [accId])) ?? 0
                let devices = (try? Int.fetchOne(db, sql: "SELECT COUNT(*) FROM devices WHERE account_id = ?", arguments: [accId])) ?? 0
                let profiles = (try? Int.fetchOne(db, sql: "SELECT COUNT(*) FROM profiles WHERE account_id = ?", arguments: [accId])) ?? 0
                return AccountWidgetData(id: accId, name: name, certCount: certs, deviceCount: devices, profileCount: profiles)
            }
        }) ?? []
    }
}
