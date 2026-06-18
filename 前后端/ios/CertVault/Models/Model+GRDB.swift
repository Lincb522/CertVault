import Foundation
import GRDB

// MARK: - Account

extension Account: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "accounts"

    enum Columns: String, ColumnExpression {
        case id, name, issuer_id, key_id, created_at, remote_synced
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["issuer_id"] = issuer_id
        container["key_id"] = key_id
        container["created_at"] = created_at
        container["remote_synced"] = remote_synced
    }
}

// MARK: - Device

extension Device: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "devices"

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["udid"] = udid
        container["platform"] = platform
        container["status"] = status
        container["device_class"] = device_class
        container["model"] = model
        container["account_id"] = account_id
        container["apple_id"] = apple_id
        container["created_at"] = created_at
    }
}

// MARK: - Certificate

extension Certificate: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "certificates"

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["type"] = type
        container["platform"] = platform
        container["serial_number"] = serial_number
        container["expires_at"] = expires_at
        container["created_at"] = created_at
        container["p12_path"] = p12_path
        container["password"] = password
        container["has_p12"] = has_p12
        container["has_private_key"] = has_private_key
        container["cert_content"] = cert_content
        container["account_id"] = account_id
        container["apple_id"] = apple_id
        container["status"] = status
    }
}

// MARK: - Profile

extension Profile: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profiles"

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["type"] = type
        container["profile_path"] = profile_path
        container["has_file"] = has_file
        container["bundle_id"] = bundle_id
        container["account_id"] = account_id
        container["apple_id"] = apple_id
        container["expires_at"] = expires_at
        container["created_at"] = created_at
        container["status"] = status
    }
}

// MARK: - BundleIDItem

extension BundleIDItem: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "bundleIds"

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["identifier"] = identifier
        container["platform"] = platform
        container["account_id"] = account_id
        container["apple_id"] = apple_id
        container["created_at"] = created_at
    }
}

// MARK: - PushKey

extension PushKey: TableRecord, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pushKeys"

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["key_id"] = key_id
        container["team_id"] = team_id
        container["bundle_ids"] = bundle_ids
        container["created_at"] = created_at
    }
}
