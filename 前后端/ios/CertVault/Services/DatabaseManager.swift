import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    private(set) var dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let dbURL: URL

            if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) {
                let groupDB = groupURL.appendingPathComponent("certvault.sqlite")
                let oldAppSupport = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let oldDB = oldAppSupport.appendingPathComponent("certvault.sqlite")
                if fileManager.fileExists(atPath: oldDB.path) && !fileManager.fileExists(atPath: groupDB.path) {
                    try fileManager.copyItem(at: oldDB, to: groupDB)
                    for suffix in ["-wal", "-shm"] {
                        let src = oldDB.appendingPathExtension(suffix.trimmingCharacters(in: ["-"]))
                        let srcAlt = URL(fileURLWithPath: oldDB.path + suffix)
                        let dst = URL(fileURLWithPath: groupDB.path + suffix)
                        if fileManager.fileExists(atPath: srcAlt.path) {
                            try? fileManager.copyItem(at: srcAlt, to: dst)
                        } else if fileManager.fileExists(atPath: src.path) {
                            try? fileManager.copyItem(at: src, to: dst)
                        }
                    }
                    AppLogger.data.info("Database migrated to App Group container")
                }
                dbURL = groupDB
            } else {
                let appSupport = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                dbURL = appSupport.appendingPathComponent("certvault.sqlite")
            }

            dbQueue = try DatabaseQueue(path: dbURL.path)
            try migrate()
        } catch {
            AppLogger.data.error("Database init failed: \(error). Using in-memory fallback.")
            dbQueue = try! DatabaseQueue()
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_createTables") { db in
            try db.create(table: "accounts", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("issuer_id", .text)
                t.column("key_id", .text)
                t.column("created_at", .text)
                t.column("remote_synced", .boolean)
            }

            try db.create(table: "devices", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("udid", .text)
                t.column("platform", .text)
                t.column("status", .text)
                t.column("device_class", .text)
                t.column("model", .text)
                t.column("account_id", .text)
                t.column("apple_id", .text)
                t.column("created_at", .text)
            }

            try db.create(table: "certificates", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("type", .text)
                t.column("platform", .text)
                t.column("serial_number", .text)
                t.column("expires_at", .text)
                t.column("created_at", .text)
                t.column("p12_path", .text)
                t.column("password", .text)
                t.column("has_p12", .boolean)
                t.column("has_private_key", .boolean)
                t.column("cert_content", .text)
                t.column("account_id", .text)
                t.column("apple_id", .text)
                t.column("status", .text)
            }

            try db.create(table: "profiles", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("type", .text)
                t.column("profile_path", .text)
                t.column("has_file", .boolean)
                t.column("bundle_id", .text)
                t.column("account_id", .text)
                t.column("apple_id", .text)
                t.column("expires_at", .text)
                t.column("created_at", .text)
                t.column("status", .text)
            }

            try db.create(table: "bundleIds", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("identifier", .text)
                t.column("platform", .text)
                t.column("account_id", .text)
                t.column("apple_id", .text)
                t.column("created_at", .text)
            }

            try db.create(table: "pushKeys", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text)
                t.column("key_id", .text)
                t.column("team_id", .text)
                t.column("bundle_ids", .text)
                t.column("created_at", .text)
            }
        }

        migrator.registerMigration("v2_submitTemplates") { db in
            try db.create(table: "submit_templates", ifNotExists: true) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("locale", .text)
                t.column("whats_new", .text)
                t.column("description", .text)
                t.column("keywords", .text)
                t.column("promotional_text", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Accounts

    func saveAccounts(_ items: [Account]) throws {
        try dbQueue.write { db in
            for item in items {
                try item.save(db, onConflict: .replace)
            }
        }
    }

    func fetchAccounts() throws -> [Account] {
        try dbQueue.read { db in
            try Account.fetchAll(db)
        }
    }

    // MARK: - Devices

    func saveDevices(_ items: [Device], accountId: String) throws {
        try dbQueue.write { db in
            try Device.filter(Column("account_id") == accountId).deleteAll(db)
            for item in items {
                try item.save(db, onConflict: .replace)
            }
        }
    }

    func fetchDevices(accountId: String) throws -> [Device] {
        try dbQueue.read { db in
            try Device.filter(Column("account_id") == accountId).fetchAll(db)
        }
    }

    // MARK: - Certificates

    func saveCertificates(_ items: [Certificate], accountId: String) throws {
        try dbQueue.write { db in
            try Certificate.filter(Column("account_id") == accountId).deleteAll(db)
            for item in items {
                try item.save(db, onConflict: .replace)
            }
        }
    }

    func fetchCertificates(accountId: String) throws -> [Certificate] {
        try dbQueue.read { db in
            try Certificate.filter(Column("account_id") == accountId).fetchAll(db)
        }
    }

    // MARK: - Profiles

    func saveProfiles(_ items: [Profile], accountId: String) throws {
        try dbQueue.write { db in
            try Profile.filter(Column("account_id") == accountId).deleteAll(db)
            for item in items {
                try item.save(db, onConflict: .replace)
            }
        }
    }

    func fetchProfiles(accountId: String) throws -> [Profile] {
        try dbQueue.read { db in
            try Profile.filter(Column("account_id") == accountId).fetchAll(db)
        }
    }

    // MARK: - Bundle IDs

    func saveBundleIds(_ items: [BundleIDItem], accountId: String) throws {
        try dbQueue.write { db in
            try BundleIDItem.filter(Column("account_id") == accountId).deleteAll(db)
            for item in items {
                try item.save(db, onConflict: .replace)
            }
        }
    }

    func fetchBundleIds(accountId: String) throws -> [BundleIDItem] {
        try dbQueue.read { db in
            try BundleIDItem.filter(Column("account_id") == accountId).fetchAll(db)
        }
    }

    // MARK: - Push Keys

    func savePushKeys(_ items: [PushKey]) throws {
        try dbQueue.write { db in
            for item in items {
                try item.save(db, onConflict: .replace)
            }
        }
    }

    func fetchPushKeys() throws -> [PushKey] {
        try dbQueue.read { db in
            try PushKey.fetchAll(db)
        }
    }

    // MARK: - Delete by ID

    func deleteAccount(id: String) throws {
        _ = try dbQueue.write { db in
            try Account.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteDevice(id: String) throws {
        _ = try dbQueue.write { db in
            try Device.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteCertificate(id: String) throws {
        _ = try dbQueue.write { db in
            try Certificate.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteProfile(id: String) throws {
        _ = try dbQueue.write { db in
            try Profile.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteBundleId(id: String) throws {
        _ = try dbQueue.write { db in
            try BundleIDItem.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deletePushKey(id: String) throws {
        _ = try dbQueue.write { db in
            try PushKey.filter(Column("id") == id).deleteAll(db)
        }
    }

    // MARK: - Dashboard Stats (from local cache)

    func computeLocalStats() throws -> DashboardStats? {
        try dbQueue.read { db in
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

    func fetchRecentCertificatesLocal(limit: Int = 5) throws -> [RecentCertificate] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql:
                "SELECT id, name, type, expires_at, created_at FROM certificates ORDER BY created_at DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.map { row in
                RecentCertificate(
                    id: row["id"], name: row["name"],
                    type: row["type"], expires_at: row["expires_at"],
                    created_at: row["created_at"]
                )
            }
        }
    }

    func fetchRecentDevicesLocal(limit: Int = 5) throws -> [RecentDevice] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql:
                "SELECT id, name, udid, platform, created_at FROM devices ORDER BY created_at DESC LIMIT ?",
                arguments: [limit]
            )
            return rows.map { row in
                RecentDevice(
                    id: row["id"], name: row["name"],
                    udid: row["udid"], platform: row["platform"],
                    created_at: row["created_at"]
                )
            }
        }
    }

    // MARK: - Submit Templates

    func saveTemplate(_ template: SubmitTemplate) throws {
        try dbQueue.write { db in
            try template.save(db, onConflict: .replace)
        }
    }

    func fetchTemplates(type: TemplateType) throws -> [SubmitTemplate] {
        try dbQueue.read { db in
            try SubmitTemplate
                .filter(SubmitTemplate.CodingKeys.type == type)
                .order(SubmitTemplate.CodingKeys.updatedAt.desc)
                .fetchAll(db)
        }
    }

    func deleteTemplate(id: String) throws {
        _ = try dbQueue.write { db in
            try SubmitTemplate.filter(Column("id") == id).deleteAll(db)
        }
    }

    // MARK: - Cache Info

    func cacheSize() -> Int64 {
        let fm = FileManager.default
        let dbPath: String
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) {
            dbPath = groupURL.appendingPathComponent("certvault.sqlite").path
        } else {
            guard let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return 0 }
            dbPath = appSupport.appendingPathComponent("certvault.sqlite").path
        }
        var total: Int64 = 0
        for suffix in ["", "-wal", "-shm"] {
            let path = dbPath + suffix
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    func cacheRecordCount() throws -> (accounts: Int, devices: Int, certificates: Int, profiles: Int, bundleIds: Int, pushKeys: Int) {
        try dbQueue.read { db in
            let a = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM accounts") ?? 0
            let d = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM devices") ?? 0
            let c = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM certificates") ?? 0
            let p = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM profiles") ?? 0
            let b = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM bundleIds") ?? 0
            let pk = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pushKeys") ?? 0
            return (a, d, c, p, b, pk)
        }
    }

    // MARK: - Clear

    func clearAll() throws {
        try dbQueue.write { db in
            try Account.deleteAll(db)
            try Device.deleteAll(db)
            try Certificate.deleteAll(db)
            try Profile.deleteAll(db)
            try BundleIDItem.deleteAll(db)
            try PushKey.deleteAll(db)
        }
    }
}
