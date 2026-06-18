import Foundation
import GRDB

enum TemplateType: String, Codable, DatabaseValueConvertible {
    case appStore = "app_store"
    case testFlight = "test_flight"
}

struct SubmitTemplate: Identifiable, Codable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "submit_templates"

    var id: String
    var name: String
    var type: TemplateType
    var locale: String?
    var whatsNew: String?
    var desc: String?
    var keywords: String?
    var promotionalText: String?
    var createdAt: String
    var updatedAt: String

    init(
        id: String = UUID().uuidString,
        name: String,
        type: TemplateType,
        locale: String? = nil,
        whatsNew: String? = nil,
        desc: String? = nil,
        keywords: String? = nil,
        promotionalText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.locale = locale
        self.whatsNew = whatsNew
        self.desc = desc
        self.keywords = keywords
        self.promotionalText = promotionalText
        let now = ISO8601DateFormatter().string(from: Date())
        self.createdAt = now
        self.updatedAt = now
    }

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name, type, locale
        case whatsNew = "whats_new"
        case desc = "description"
        case keywords
        case promotionalText = "promotional_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
