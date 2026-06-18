import SwiftUI
import WidgetKit

struct DashboardWidgetView: View {
    let entry: DashboardEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .widgetURL(URL(string: "certvault://dashboard"))
        .widgetContainerBackground(WColor.background)
    }

    private var smallView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WColor.accentBlue)
                Spacer()
            }

            VStack(spacing: 8) {
                StatRow(icon: "lock.doc", label: "证书", value: entry.stats?.certificates ?? 0, color: WColor.accentBlue)
                StatRow(icon: "iphone", label: "设备", value: entry.stats?.devices ?? 0, color: WColor.accent)
            }

            Spacer(minLength: 0)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(WColor.accentBlue)
                    Text("CertVault")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(WColor.text)
                }
                Spacer(minLength: 0)
                Text("\(entry.stats?.accounts ?? 0) 个账号")
                    .font(.caption2)
                    .foregroundStyle(WColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    MiniStat(icon: "lock.doc", value: entry.stats?.certificates ?? 0, label: "证书", color: WColor.accentBlue)
                    MiniStat(icon: "iphone", value: entry.stats?.devices ?? 0, label: "设备", color: WColor.accent)
                }
                HStack(spacing: 8) {
                    MiniStat(icon: "doc.text", value: entry.stats?.profiles ?? 0, label: "描述文件", color: WColor.accentPurple)
                    MiniStat(icon: "shippingbox", value: entry.stats?.bundle_ids ?? 0, label: "Bundle", color: WColor.accentOrange)
                }
            }
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "shield.checkered")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WColor.accentBlue)
                Text("CertVault")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WColor.text)
                Spacer()
                Text("\(entry.stats?.accounts ?? 0) 个账号")
                    .font(.caption2)
                    .foregroundStyle(WColor.muted)
            }

            HStack(spacing: 8) {
                MiniStat(icon: "lock.doc", value: entry.stats?.certificates ?? 0, label: "证书", color: WColor.accentBlue)
                MiniStat(icon: "iphone", value: entry.stats?.devices ?? 0, label: "设备", color: WColor.accent)
                MiniStat(icon: "doc.text", value: entry.stats?.profiles ?? 0, label: "描述文件", color: WColor.accentPurple)
                MiniStat(icon: "shippingbox", value: entry.stats?.bundle_ids ?? 0, label: "Bundle", color: WColor.accentOrange)
            }

            Divider().overlay(WColor.border)

            Text("最近证书")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WColor.muted)

            if entry.recentCerts.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundStyle(WColor.muted.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(entry.recentCerts) { cert in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(WColor.accentBlue.opacity(0.15))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "lock.doc")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(WColor.accentBlue)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cert.name ?? "未命名")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(WColor.text)
                                .lineLimit(1)
                            Text(cert.type ?? "")
                                .font(.caption2)
                                .foregroundStyle(WColor.muted)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct StatRow: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(WColor.muted)
            Spacer()
            Text("\(value)")
                .font(.callout.weight(.bold))
                .foregroundStyle(WColor.text)
        }
    }
}

private struct MiniStat: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(WColor.text)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(WColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}
