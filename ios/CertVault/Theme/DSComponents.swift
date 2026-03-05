import SwiftUI
import HiconIcons

// MARK: - Card Container

struct DSCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.spacingLG)
            .cardStyle()
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    var trailing: AnyView?

    init(_ title: String) {
        self.title = title
    }

    init(_ title: String, @ViewBuilder trailing: () -> some View) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
            Spacer()
            trailing
        }
    }
}

// MARK: - Settings / Menu Row

struct DSRow: View {
    let icon: UIImage
    let iconColor: Color
    let title: String
    var subtitle: String?
    var trailing: AnyView?
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.radiusSM))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dsText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let trailing {
                trailing
            }

            if showChevron {
                HIcon(AppIcon.chevronRight)
                    .font(.caption2)
                    .foregroundStyle(Color.dsTextTertiary)
            }
        }
        .padding(.vertical, DS.spacingMD)
        .padding(.horizontal, DS.spacingLG)
        .frame(minHeight: DS.minTouchTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - Grouped Card (for lists of rows)

struct DSGroupedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *) {
            VStack(spacing: 0) { content }
                .glassEffect(.regular.tint(Color.dsSurface.opacity(0.5)), in: .rect(cornerRadius: DS.radiusLG))
        } else {
            VStack(spacing: 0) { content }
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusLG))
                .overlay(RoundedRectangle(cornerRadius: DS.radiusLG).stroke(Color.dsBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Status Badge

struct DSBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }

    static func forStatus(_ status: String) -> DSBadge {
        switch status.uppercased() {
        case "ACTIVE", "VALID", "ENABLED", "ONLINE":
            return DSBadge(text: Localized.status(status), color: .dsGreen)
        case "EXPIRED", "REVOKED", "INVALID", "DISABLED", "OFFLINE":
            return DSBadge(text: Localized.status(status), color: .dsRed)
        case "PENDING", "PROCESSING":
            return DSBadge(text: Localized.status(status), color: .dsOrange)
        case "INELIGIBLE":
            return DSBadge(text: Localized.status(status), color: .dsTextTertiary)
        default:
            return DSBadge(text: Localized.status(status), color: .dsTextSecondary)
        }
    }
}

// MARK: - Filter Chips

struct DSChipGroup: View {
    let options: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.spacingSM) {
                ForEach(options, id: \.self) { option in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeInOut(duration: 0.2)) { selected = option }
                    } label: {
                        Text(option)
                            .font(.subheadline.weight(selected == option ? .semibold : .regular))
                            .foregroundStyle(selected == option ? .white : Color.dsTextSecondary)
                            .padding(.horizontal, DS.spacingLG)
                            .padding(.vertical, DS.spacingSM)
                            .background(
                                selected == option ? AnyShapeStyle(Color.dsBrand) : AnyShapeStyle(Color.dsSurfaceElevated),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - Empty State

struct DSEmptyState: View {
    let icon: UIImage
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    @State private var pulse = false

    var body: some View {
        VStack(spacing: DS.spacingLG) {
            HIcon(icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.dsTextTertiary)
                .scaleEffect(pulse ? 1.05 : 1)
                .opacity(pulse ? 0.7 : 1)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            VStack(spacing: DS.spacingSM) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.spacing2XL)
                        .padding(.vertical, DS.spacingMD)
                        .background(Color.dsBrand, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Input Field (simple text binding)

struct DSInputField: View {
    let icon: UIImage
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(isFocused ? Color.dsBrand : Color.dsTextSecondary)
                .frame(width: 20)

            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.dsTextTertiary))
                    .foregroundStyle(Color.dsText)
                    .focused($isFocused)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.dsTextTertiary))
                    .foregroundStyle(Color.dsText)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, 14)
        .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMD)
                .stroke(isFocused ? Color.dsBrand : Color.dsBorder, lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Input Field (custom content builder, used by RegisterView etc.)

struct DSInputFieldBuilder<Content: View>: View {
    let icon: UIImage
    var focused: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(focused ? Color.dsBrand : Color.dsTextSecondary)
                .frame(width: 20)
            content
        }
        .padding(.horizontal, DS.spacingLG)
        .padding(.vertical, 14)
        .background(Color.dsSurfaceElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusMD)
                .stroke(focused ? Color.dsBrand : Color.dsBorder, lineWidth: focused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: focused)
    }
}

// MARK: - Primary Button

struct DSPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: DS.spacingSM) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Danger Button

struct DSDangerButton: View {
    let title: String
    let icon: UIImage?
    let action: () -> Void

    init(_ title: String, icon: UIImage? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.spacingSM) {
                if let icon { HIcon(icon).font(.callout) }
                Text(title).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color.dsDanger)
            .background(Color.dsDanger.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusMD))
            .overlay(RoundedRectangle(cornerRadius: DS.radiusMD).stroke(Color.dsDanger.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - List Row Divider

struct DSDivider: View {
    var leadingPadding: CGFloat = 56

    var body: some View {
        Divider()
            .overlay(Color.dsDivider)
            .padding(.leading, leadingPadding)
    }
}

// MARK: - Pressed Button Style

struct DSPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSPressedStyle {
    static var dsPressed: DSPressedStyle { DSPressedStyle() }
}

// MARK: - Staggered Fade-In Modifier

struct StaggeredAppear: ViewModifier {
    let index: Int
    let animate: Bool

    func body(content: Content) -> some View {
        content
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 12)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.85)
                    .delay(Double(index) * 0.04),
                value: animate
            )
    }
}

extension View {
    func staggeredAppear(index: Int, animate: Bool) -> some View {
        modifier(StaggeredAppear(index: index, animate: animate))
    }
}

// MARK: - Haptic Feedback Helpers

enum DSHaptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
