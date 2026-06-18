import WidgetKit
import SwiftUI

struct DashboardEntry: TimelineEntry {
    let date: Date
    let stats: DashboardStats?
    let recentCerts: [RecentCertificate]
}

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(
            date: .now,
            stats: DashboardStats(accounts: 3, devices: 12, certificates: 8, certs_with_p12: nil, profiles: 15, bundle_ids: 6),
            recentCerts: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        let data = WidgetDataProvider.shared
        completion(DashboardEntry(
            date: .now,
            stats: data.fetchStats(),
            recentCerts: data.fetchRecentCertificates(limit: 3)
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        let data = WidgetDataProvider.shared
        let entry = DashboardEntry(
            date: .now,
            stats: data.fetchStats(),
            recentCerts: data.fetchRecentCertificates(limit: 3)
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct DashboardWidget: Widget {
    let kind = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("仪表盘")
        .description("证书、设备、描述文件数量概览")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
