import WidgetKit
import SwiftUI

struct AccountEntry: TimelineEntry {
    let date: Date
    let accounts: [AccountWidgetData]
}

struct AccountProvider: TimelineProvider {
    func placeholder(in context: Context) -> AccountEntry {
        AccountEntry(date: .now, accounts: [
            AccountWidgetData(id: "1", name: "My Team", certCount: 5, deviceCount: 10, profileCount: 8),
            AccountWidgetData(id: "2", name: "Client Team", certCount: 3, deviceCount: 6, profileCount: 4),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (AccountEntry) -> Void) {
        completion(AccountEntry(date: .now, accounts: WidgetDataProvider.shared.fetchAccountStatus()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AccountEntry>) -> Void) {
        let entry = AccountEntry(date: .now, accounts: WidgetDataProvider.shared.fetchAccountStatus())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct AccountWidget: Widget {
    let kind = "AccountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AccountProvider()) { entry in
            AccountWidgetView(entry: entry)
        }
        .configurationDisplayName("账号状态")
        .description("各开发者账号的资源统计")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
