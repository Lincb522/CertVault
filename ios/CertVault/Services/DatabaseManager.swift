import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = appSupport.appendingPathComponent("certvault.sqlite")
            dbQueue = try DatabaseQueue(path: dbURL.path)
            try migrate()
        } catch {
            fatalError("Database init failed: \(error)")
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
        try dbQueue.write { db in
            try Account.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteDevice(id: String) throws {
        try dbQueue.write { db in
            try Device.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteCertificate(id: String) throws {
        try dbQueue.write { db in
            try Certificate.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteProfile(id: String) throws {
        try dbQueue.write { db in
            try Profile.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deleteBundleId(id: String) throws {
        try dbQueue.write { db in
            try BundleIDItem.filter(Column("id") == id).deleteAll(db)
        }
    }

    func deletePushKey(id: String) throws {
        try dbQueue.write { db in
            try PushKey.filter(Column("id") == id).deleteAll(db)
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
