import SwiftUI
import HiconIcons

struct StatCard: View {
    let title: String
    let value: String
    let icon: UIImage
    let color: Color
    let trend: String?

    init(title: String, value: String, icon: UIImage,
         gradient: [Color] = [.dsAccentBlue, .dsAccentPurple],
         trend: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = gradient.first ?? .dsAccentBlue
        self.trend = trend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                iconView
                Spacer()
                if let trend {
                    Text(trend)
                        .font(.caption2.weight(.semibold).monospaced())
                        .foregroundStyle(Color.dsAccent)
                }
            }

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dsText)
                .contentTransition(.numericText())

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.dsMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .modifier(StatCardBackground(color: color))
    }

    private var iconView: some View {
        HIcon(icon)
            .font(.body)
            .foregroundStyle(color)
            .padding(8)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatCardBackground: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(color.opacity(0.15)),
                    in: .rect(cornerRadius: 16)
                )
        } else {
            content
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(color.opacity(0.06))
                        .frame(width: 80, height: 80)
                        .offset(x: 20, y: -20)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
