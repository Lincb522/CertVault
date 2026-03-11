import SwiftUI
import WidgetKit

struct AccountWidgetView: View {
    let entry: AccountEntry
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
        .widgetURL(URL(string: "certvault://accounts"))
        .widgetContainerBackground(WColor.background)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WColor.accentPurple)
                Text("账号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WColor.text)
                Spacer()
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("\(entry.accounts.count)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(WColor.text)
                Text("个账号")
                    .font(.caption)
                    .foregroundStyle(WColor.muted)
            }

            let totalCerts = entry.accounts.reduce(0) { $0 + $1.certCount }
            let totalDevices = entry.accounts.reduce(0) { $0 + $1.deviceCount }
            HStack(spacing: 12) {
                Label("\(totalCerts)", systemImage: "lock.doc")
                    .font(.caption2)
                    .foregroundStyle(WColor.muted)
                Label("\(totalDevices)", systemImage: "iphone")
                    .font(.caption2)
                    .foregroundStyle(WColor.muted)
            }
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.2")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WColor.accentPurple)
                Text("账号状态")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WColor.text)
                Spacer()
                Text("\(entry.accounts.count) 个账号")
                    .font(.system(size: 9))
                    .foregroundStyle(WColor.muted)
            }

            if entry.accounts.isEmpty {
                Spacer()
                Text("暂无账号数据")
                    .font(.caption)
                    .foregroundStyle(WColor.muted)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.accounts.prefix(3)) { acc in
                    accountRowCompact(acc)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(WColor.accentPurple)
                Text("账号状态")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WColor.text)
                Spacer()
                Text("\(entry.accounts.count) 个账号")
                    .font(.caption2)
                    .foregroundStyle(WColor.muted)
            }

            Divider().overlay(WColor.border)

            if entry.accounts.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(WColor.muted)
                    Text("暂无账号数据")
                        .font(.caption)
                        .foregroundStyle(WColor.muted)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.accounts.prefix(5)) { acc in
                    accountRowDetailed(acc)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func accountRowCompact(_ acc: AccountWidgetData) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WColor.accentPurple.opacity(0.15))
                .frame(width: 22, height: 22)
                .overlay(
                    Text(String(acc.name.prefix(1)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WColor.accentPurple)
                )
            Text(acc.name)
                .font(.caption)
                .foregroundStyle(WColor.text)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 6) {
                Label("\(acc.certCount)", systemImage: "lock.doc")
                Label("\(acc.deviceCount)", systemImage: "iphone")
            }
            .font(.system(size: 9))
            .foregroundStyle(WColor.muted)
        }
    }

    private func accountRowDetailed(_ acc: AccountWidgetData) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(WColor.accentPurple.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(acc.name.prefix(1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WColor.accentPurple)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(acc.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WColor.text)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    StatLabel(icon: "lock.doc", value: acc.certCount, color: WColor.accentBlue)
                    StatLabel(icon: "iphone", value: acc.deviceCount, color: WColor.accent)
                    StatLabel(icon: "doc.text", value: acc.profileCount, color: WColor.accentPurple)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct StatLabel: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WColor.muted)
        }
    }
}
