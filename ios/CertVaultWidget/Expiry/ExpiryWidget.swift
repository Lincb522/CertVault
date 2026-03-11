import WidgetKit
import SwiftUI

struct ExpiryEntry: TimelineEntry {
    let date: Date
    let items: [ExpiringItem]
}

struct ExpiryProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpiryEntry {
        ExpiryEntry(date: .now, items: [
            ExpiringItem(id: "1", name: "iOS Distribution", type: "Distribution", kind: .certificate,
                         expiresAt: Date().addingTimeInterval(86400 * 7), daysLeft: 7),
            ExpiringItem(id: "2", name: "Ad Hoc Profile", type: "Ad Hoc", kind: .profile,
                         expiresAt: Date().addingTimeInterval(86400 * 14), daysLeft: 14),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpiryEntry) -> Void) {
        completion(ExpiryEntry(date: .now, items: WidgetDataProvider.shared.fetchExpiringItems(limit: 5)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpiryEntry>) -> Void) {
        let entry = ExpiryEntry(date: .now, items: WidgetDataProvider.shared.fetchExpiringItems(limit: 5))
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct ExpiryWidget: Widget {
    let kind = "ExpiryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpiryProvider()) { entry in
            ExpiryWidgetView(entry: entry)
        }
        .configurationDisplayName("到期提醒")
        .description("显示即将到期的证书和描述文件")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
