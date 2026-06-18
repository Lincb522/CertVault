import Foundation

final class PushStorage {
    static let shared = PushStorage()
    private init() {}

    private let bundleIdsKey = "push_saved_bundle_ids"
    private let templatesKey = "push_saved_templates"
    private let maxBundleIds = 20

    // MARK: - Bundle ID History

    var savedBundleIds: [String] {
        UserDefaults.standard.stringArray(forKey: bundleIdsKey) ?? []
    }

    func saveBundleId(_ id: String) {
        guard !id.isEmpty else { return }
        var list = savedBundleIds.filter { $0 != id }
        list.insert(id, at: 0)
        if list.count > maxBundleIds { list = Array(list.prefix(maxBundleIds)) }
        UserDefaults.standard.set(list, forKey: bundleIdsKey)
    }

    func removeBundleId(_ id: String) {
        let list = savedBundleIds.filter { $0 != id }
        UserDefaults.standard.set(list, forKey: bundleIdsKey)
    }

    // MARK: - Push Templates

    var savedTemplates: [PushTemplate] {
        guard let data = UserDefaults.standard.data(forKey: templatesKey),
              let templates = try? JSONDecoder().decode([PushTemplate].self, from: data) else {
            return Self.builtInTemplates
        }
        return templates.isEmpty ? Self.builtInTemplates : templates
    }

    static let builtInTemplates: [PushTemplate] = [
        PushTemplate(id: "builtin_test", name: "🔔 推送测试",
                     title: "推送测试", body: "这是一条测试推送消息，如果你看到了说明推送通道正常。",
                     badge: 1, sound: "default"),
        PushTemplate(id: "builtin_silent", name: "🔇 静默推送",
                     title: "", body: "",
                     sound: nil, mutableContent: true, priority: "5"),
        PushTemplate(id: "builtin_update", name: "🆕 版本更新",
                     title: "新版本可用", body: "新版本已发布，包含重要更新和问题修复，建议尽快更新。",
                     badge: 1, sound: "default"),
        PushTemplate(id: "builtin_cert_expire", name: "⚠️ 证书到期",
                     title: "证书即将到期", body: "您有证书将在 7 天内到期，请及时续期以免影响应用分发。",
                     sound: "default", interruptionLevel: "time-sensitive"),
        PushTemplate(id: "builtin_maintenance", name: "🔧 系统维护",
                     title: "系统维护通知", body: "系统将于今晚 22:00-次日 02:00 进行维护升级，届时部分服务可能不可用。",
                     sound: "default"),
        PushTemplate(id: "builtin_welcome", name: "👋 欢迎消息",
                     title: "欢迎使用", body: "感谢您注册，开始探索所有功能吧！",
                     badge: 0, sound: "default"),
        PushTemplate(id: "builtin_urgent", name: "🚨 紧急通知",
                     title: "紧急通知", body: "检测到异常情况，请立即查看并处理。",
                     sound: "default", interruptionLevel: "critical"),
        PushTemplate(id: "builtin_task_done", name: "✅ 任务完成",
                     title: "任务完成", body: "您的操作已完成，点击查看详情。",
                     sound: "default", interruptionLevel: "passive"),
    ]

    func saveTemplate(_ template: PushTemplate) {
        var list = savedTemplates
        if let idx = list.firstIndex(where: { $0.id == template.id }) {
            list[idx] = template
        } else {
            list.insert(template, at: 0)
        }
        persist(list)
    }

    func deleteTemplate(id: String) {
        let list = savedTemplates.filter { $0.id != id }
        persist(list)
    }

    private func persist(_ templates: [PushTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: templatesKey)
        }
    }
}

struct PushTemplate: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var title: String
    var body: String
    var badge: Int?
    var sound: String?
    var threadId: String?
    var collapseId: String?
    var mutableContent: Bool?
    var interruptionLevel: String?
    var priority: String?

    var displayName: String { name.isEmpty ? title : name }
}
