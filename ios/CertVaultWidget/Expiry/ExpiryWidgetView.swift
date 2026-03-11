import SwiftUI
import WidgetKit

struct ExpiryWidgetView: View {
    let entry: ExpiryEntry
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
        .widgetURL(URL(string: "certvault://certificates"))
        .widgetContainerBackground(WColor.background)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WColor.accentOrange)
                Text("到期提醒")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WColor.text)
                Spacer()
            }

            if let first = entry.items.first {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(first.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WColor.text)
                        .lineLimit(2)
                    Text(first.kind.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(WColor.muted)
                    HStack(spacing: 4) {
                        Text(daysLabel(first.daysLeft))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(urgencyColor(first.daysLeft))
                        Text("天")
                            .font(.caption)
                            .foregroundStyle(WColor.muted)
                    }
                }
                Spacer(minLength: 0)
            } else {
                Spacer()
                Text("全部正常")
                    .font(.caption)
                    .foregroundStyle(WColor.accent)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WColor.accentOrange)
                Text("到期提醒")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WColor.text)
                Spacer()
                Text("90 天内")
                    .font(.system(size: 9))
                    .foregroundStyle(WColor.muted)
            }

            if entry.items.isEmpty {
                Spacer()
                Text("所有证书和描述文件状态正常")
                    .font(.caption)
                    .foregroundStyle(WColor.accent)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    expiryRow(item)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WColor.accentOrange)
                Text("到期提醒")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WColor.text)
                Spacer()
                Text("\(entry.items.count) 项即将到期")
                    .font(.caption2)
                    .foregroundStyle(WColor.muted)
            }

            Divider().overlay(WColor.border)

            if entry.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.largeTitle)
                        .foregroundStyle(WColor.accent)
                    Text("所有证书和描述文件状态正常")
                        .font(.caption)
                        .foregroundStyle(WColor.muted)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.items.prefix(5)) { item in
                    expiryRowDetailed(item)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func expiryRow(_ item: ExpiringItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(urgencyColor(item.daysLeft).opacity(0.15))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: item.kind == .certificate ? "lock.doc" : "doc.text")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(urgencyColor(item.daysLeft))
                )
            Text(item.name)
                .font(.caption)
                .foregroundStyle(WColor.text)
                .lineLimit(1)
            Spacer()
            Text("\(item.daysLeft)天")
                .font(.caption.weight(.bold))
                .foregroundStyle(urgencyColor(item.daysLeft))
        }
    }

    private func expiryRowDetailed(_ item: ExpiringItem) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(urgencyColor(item.daysLeft))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WColor.text)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.kind.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(WColor.muted)
                    Text("·")
                        .foregroundStyle(WColor.muted)
                    Text(item.type)
                        .font(.system(size: 9))
                        .foregroundStyle(WColor.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(item.daysLeft)")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(urgencyColor(item.daysLeft))
                Text("天")
                    .font(.system(size: 9))
                    .foregroundStyle(WColor.muted)
            }
        }
    }

    private func urgencyColor(_ days: Int) -> Color {
        if days <= 0 { return WColor.accentPink }
        if days <= 7 { return WColor.accentPink }
        if days <= 30 { return WColor.accentOrange }
        return WColor.accent
    }

    private func daysLabel(_ days: Int) -> String {
        if days <= 0 { return "已过期" }
        return "\(days)"
    }
}
