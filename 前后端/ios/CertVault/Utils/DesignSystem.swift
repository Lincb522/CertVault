import SwiftUI
import HiconIcons

// MARK: - Design Tokens

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum IconSize {
        static let sm: CGFloat = 32
        static let md: CGFloat = 36
        static let lg: CGFloat = 40
        static let xl: CGFloat = 48
    }

    enum Animation {
        static let fast: SwiftUI.Animation = .easeOut(duration: 0.15)
        static let normal: SwiftUI.Animation = .easeOut(duration: 0.25)
        static let spring: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.8)
    }
}

// MARK: - Icon Badge (colored icon with background)

struct IconBadge: View {
    let icon: UIImage
    let color: Color
    var size: CGFloat = DS.IconSize.lg
    var cornerRadius: CGFloat = DS.Radius.md

    var body: some View {
        HIcon(icon)
            .font(size > 36 ? .body : .callout)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Gradient Icon Badge

struct GradientIconBadge: View {
    let icon: UIImage
    let color: Color
    var size: CGFloat = DS.IconSize.lg

    var body: some View {
        HIcon(icon)
            .font(.body)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [color, color.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
    }
}

// MARK: - List Row (standard row for navigation lists)

struct DSListRow: View {
    let icon: UIImage
    let color: Color
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var badge: String? = nil
    var badgeColor: Color? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(icon: icon, color: color)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.dsText)
                        .lineLimit(1)
                    if let badge, let badgeColor {
                        StatusBadge(badge, color: badgeColor)
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dsMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let trailing {
                Text(trailing)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.dsMuted.opacity(0.6))
            }

            if showChevron {
                HIcon(AppIcon.chevronRight)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.dsMuted.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Stat Pill (compact inline stat)

struct StatPill: View {
    let label: String
    let value: String
    var color: Color = .dsAccentBlue

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dsMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: Capsule())
    }
}

// MARK: - Stats Bar (horizontal stat chips row)

struct StatsBar: View {
    let items: [(label: String, value: Int, color: Color)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                StatPill(label: item.label, value: "\(item.value)", color: item.color)
            }
        }
    }
}

// MARK: - Inline Stat Grid (compact stats in a glass card)

struct InlineStatGrid: View {
    let items: [(label: String, value: Int, color: Color)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 3) {
                    Text("\(item.value)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(item.color)
                        .contentTransition(.numericText())
                    Text(item.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.dsMuted)
                }
                .frame(maxWidth: .infinity)
                if index < items.count - 1 {
                    Divider().frame(height: 28)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .glassCard(cornerRadius: DS.Radius.lg)
    }
}

// MARK: - Filter Chip Bar

struct FilterChipBar: View {
    let options: [(id: String, label: String)]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.id) { option in
                    Button { selection = option.id } label: {
                        Text(option.label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundStyle(selection == option.id ? .white : Color.dsMuted)
                            .background(
                                selection == option.id
                                    ? AnyShapeStyle(Color.dsAccentBlue)
                                    : AnyShapeStyle(.ultraThinMaterial),
                                in: Capsule()
                            )
                    }
                    .animation(.easeInOut(duration: 0.2), value: selection)
                }
            }
        }
    }
}

// MARK: - Info Row (key-value pair for detail views)

struct InfoRow: View {
    let label: String
    let value: String
    var monoValue: Bool = false
    var selectable: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.dsMuted)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
            if selectable {
                Text(value)
                    .font(monoValue ? .caption.monospaced() : .subheadline)
                    .foregroundStyle(Color.dsText)
                    .textSelection(.enabled)
                    .lineLimit(2)
            } else {
                Text(value)
                    .font(monoValue ? .caption.monospaced() : .subheadline)
                    .foregroundStyle(Color.dsText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Section Title

struct DSSectionTitle: View {
    let text: String
    var icon: UIImage? = nil
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                HIcon(icon)
                    .font(.caption)
                    .foregroundStyle(Color.dsMuted)
            }
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dsMuted)
            if let count {
                Text("\(count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.dsAccentBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.dsAccentBlue.opacity(0.1), in: Capsule())
            }
            Spacer()
        }
    }
}

// MARK: - Type Badge (small colored label)

struct TypeBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Meta Label (small key-value pair)

struct MetaLabel: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 2) {
            Text(label).foregroundStyle(Color.dsMuted)
            Text(value).foregroundStyle(Color.dsText)
        }
        .font(.caption2)
        .lineLimit(1)
    }
}

// MARK: - Glass Section (grouped card with title)

struct GlassSection<Content: View>: View {
    let title: String
    var icon: UIImage? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DSSectionTitle(text: title, icon: icon)
            VStack(spacing: 0) {
                content()
            }
            .glassCard(cornerRadius: DS.Radius.lg)
        }
    }
}

// MARK: - Toolbar Close Button

struct ToolbarCloseButton: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.cancel, action: action)
        }
    }
}

// MARK: - Color Helpers

extension Color {
    static let dsSuccess = Color.dsAccent
    static let dsWarning = Color.dsAccentOrange
    static let dsDanger = Color.dsAccentPink
    static let dsInfo = Color.dsAccentBlue

    static func forStatus(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "success", "active", "enabled", "valid": return .dsSuccess
        case "partial", "pending", "processing": return .dsWarning
        case "failed", "error", "expired", "revoked", "disabled": return .dsDanger
        default: return .dsMuted
        }
    }

    static var orangeGradient: LinearGradient {
        LinearGradient(
            colors: [.dsAccentOrange, Color(red: 0.90, green: 0.45, blue: 0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var pinkGradient: LinearGradient {
        LinearGradient(
            colors: [.dsAccentPink, Color(red: 0.80, green: 0.20, blue: 0.50)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cyanGradient: LinearGradient {
        LinearGradient(
            colors: [.dsAccentCyan, Color(red: 0.04, green: 0.60, blue: 0.70)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Extensions

extension View {
    func dsListCard() -> some View {
        self
            .padding(.vertical, 4)
            .glassCard(cornerRadius: DS.Radius.lg)
    }

    @ViewBuilder
    func glassTinted(_ color: Color, cornerRadius: CGFloat = DS.Radius.lg) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                .regular.tint(color.opacity(0.12)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
                .glassCard(cornerRadius: cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        }
    }

    func staggeredAnimation(index: Int, trigger: Bool) -> some View {
        self
            .opacity(trigger ? 1 : 0)
            .offset(y: trigger ? 0 : 12)
            .animation(
                .easeOut(duration: 0.35).delay(Double(index) * 0.06),
                value: trigger
            )
    }
}

// MARK: - Device Model Name

enum DeviceInfo {
    static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }

    static var modelName: String {
        let id = machineIdentifier
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return modelMap[sim] ?? sim
        }
        return modelMap[id] ?? id
    }

    private static let modelMap: [String: String] = [
        // MARK: iPhone
        "iPhone8,1": "iPhone 6s", "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1st)",
        "iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        // 2025
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        // 2026
        "iPhone18,5": "iPhone 17e",

        // MARK: iPad
        "iPad11,1": "iPad mini (5th)", "iPad11,2": "iPad mini (5th)",
        "iPad11,3": "iPad Air (3rd)", "iPad11,4": "iPad Air (3rd)",
        "iPad11,6": "iPad (8th)", "iPad11,7": "iPad (8th)",
        "iPad12,1": "iPad (9th)", "iPad12,2": "iPad (9th)",
        "iPad13,1": "iPad Air (4th)", "iPad13,2": "iPad Air (4th)",
        "iPad13,4": "iPad Pro 11-inch (3rd)", "iPad13,5": "iPad Pro 11-inch (3rd)",
        "iPad13,6": "iPad Pro 11-inch (3rd)", "iPad13,7": "iPad Pro 11-inch (3rd)",
        "iPad13,8": "iPad Pro 12.9-inch (5th)", "iPad13,9": "iPad Pro 12.9-inch (5th)",
        "iPad13,10": "iPad Pro 12.9-inch (5th)", "iPad13,11": "iPad Pro 12.9-inch (5th)",
        "iPad13,16": "iPad Air (5th)", "iPad13,17": "iPad Air (5th)",
        "iPad13,18": "iPad (10th)", "iPad13,19": "iPad (10th)",
        "iPad14,1": "iPad mini (6th)", "iPad14,2": "iPad mini (6th)",
        "iPad14,3": "iPad Pro 11-inch (4th)", "iPad14,4": "iPad Pro 11-inch (4th)",
        "iPad14,5": "iPad Pro 12.9-inch (6th)", "iPad14,6": "iPad Pro 12.9-inch (6th)",
        "iPad14,8": "iPad Air 11-inch (M2)", "iPad14,9": "iPad Air 11-inch (M2)",
        "iPad14,10": "iPad Air 13-inch (M2)", "iPad14,11": "iPad Air 13-inch (M2)",
        // 2025
        "iPad15,7": "iPad (11th)", "iPad15,8": "iPad (11th)",
        "iPad16,1": "iPad mini (A17 Pro)", "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11-inch (M4)", "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)", "iPad16,6": "iPad Pro 13-inch (M4)",
        // 2026
        "iPad16,8": "iPad Air 11-inch (M4)", "iPad16,9": "iPad Air 11-inch (M4)",
        "iPad16,10": "iPad Air 13-inch (M4)", "iPad16,11": "iPad Air 13-inch (M4)",

        // MARK: iPod
        "iPod9,1": "iPod touch (7th)",
    ]
}
