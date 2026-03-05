import SwiftUI
import HiconIcons

// MARK: - Grouped Card (list container)

struct DSGroupedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *) {
            VStack(spacing: 0) { content }
                .glassEffect(.regular.tint(Color.dsSurface.opacity(0.5)), in: .rect(cornerRadius: DS.radiusXL))
        } else {
            VStack(spacing: 0) { content }
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusXL))
                .overlay(RoundedRectangle(cornerRadius: DS.radiusXL).stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Gradient Card

struct DSGradientCard<Content: View>: View {
    let gradient: LinearGradient
    let content: Content

    init(gradient: LinearGradient, @ViewBuilder content: () -> Content) {
        self.gradient = gradient
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(gradient, in: RoundedRectangle(cornerRadius: DS.radiusXXL))
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Stat Card

struct DSStatCard: View {
    let title: String
    let value: String
    let icon: UIImage
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacingSM) {
            HStack {
                HIcon(icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }

            Text(value)
                .font(.dsStatLarge)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(DS.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(gradient, in: RoundedRectangle(cornerRadius: DS.radiusXXL))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Action Card

struct DSActionCard: View {
    let title: String
    let icon: UIImage
    let gradient: LinearGradient
    var action: (() -> Void)?

    var body: some View {
        Button {
            DSHaptic.light()
            action?()
        } label: {
            VStack(spacing: DS.spacingSM) {
                HIcon(icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: DS.radiusMD))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.spacingLG)
            .padding(.horizontal, DS.spacingSM)
            .background(gradient, in: RoundedRectangle(cornerRadius: DS.radiusXL))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.dsPressed)
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
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dsText)
            Spacer()
            trailing
        }
    }
}

// MARK: - Row (for lists & menus)

struct DSRow: View {
    let icon: UIImage
    let iconColor: Color
    let title: String
    var subtitle: String?
    var trailing: AnyView?
    var showChevron: Bool = true
    var useGradientIcon: Bool = false

    var body: some View {
        HStack(spacing: DS.spacingMD) {
            HIcon(icon)
                .font(.callout)
                .foregroundStyle(useGradientIcon ? .white : iconColor)
                .frame(width: 34, height: 34)
                .background {
                    if useGradientIcon {
                        RoundedRectangle(cornerRadius: DS.radiusSM + 2)
                            .fill(iconColor.gradient)
                    } else {
                        RoundedRectangle(cornerRadius: DS.radiusSM + 2)
                            .fill(iconColor.opacity(0.12))
                    }
                }

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

            if let trailing { trailing }

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

// MARK: - Status Badge

struct DSBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    static func forStatus(_ status: String) -> DSBadge {
        let label = Localized.status(status)
        switch status.uppercased() {
        case "ACTIVE", "VALID", "ENABLED", "ONLINE":
            return DSBadge(text: label, color: .dsGreen)
        case "EXPIRED", "REVOKED", "INVALID", "DISABLED", "OFFLINE":
            return DSBadge(text: label, color: .dsRed)
        case "PENDING", "PROCESSING":
            return DSBadge(text: label, color: .dsOrange)
        case "INELIGIBLE":
            return DSBadge(text: label, color: .dsTextTertiary)
        default:
            return DSBadge(text: label, color: .dsTextSecondary)
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
                        DSHaptic.selection()
                        withAnimation(.easeInOut(duration: 0.2)) { selected = option }
                    } label: {
                        Text(option)
                            .font(.subheadline.weight(selected == option ? .semibold : .regular))
                            .foregroundStyle(selected == option ? .white : Color.dsTextSecondary)
                            .padding(.horizontal, DS.spacingLG)
                            .padding(.vertical, DS.spacingSM)
                            .background {
                                if selected == option {
                                    Capsule().fill(Color.dsBrandGradient)
                                } else {
                                    Capsule().fill(Color.dsSurfaceElevated)
                                }
                            }
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
                .font(.system(size: 44))
                .foregroundStyle(Color.dsTextTertiary)
                .scaleEffect(pulse ? 1.05 : 1)
                .opacity(pulse ? 0.7 : 1)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            VStack(spacing: DS.spacingSM) {
                Text(title)
                    .font(.headline.weight(.bold))
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
                        .background(Color.dsBrandGradient, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Input Field

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
                .stroke(isFocused ? Color.dsBrand : Color.dsBorder.opacity(0.5), lineWidth: isFocused ? 1.5 : 0.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
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
            DSHaptic.light()
            action()
        }) {
            HStack(spacing: DS.spacingSM) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.body.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(Color.dsBrandGradient, in: RoundedRectangle(cornerRadius: DS.radiusMD))
            .shadow(color: Color.dsBlue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .scaleEffect(isPressed ? 0.97 : 1)
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
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.dsDanger)
            .background(Color.dsDanger.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.radiusMD))
            .overlay(RoundedRectangle(cornerRadius: DS.radiusMD).stroke(Color.dsDanger.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - Divider

struct DSDivider: View {
    var leadingPadding: CGFloat = 60

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
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSPressedStyle {
    static var dsPressed: DSPressedStyle { DSPressedStyle() }
}

// MARK: - Staggered Appear

struct StaggeredAppear: ViewModifier {
    let index: Int
    let animate: Bool

    func body(content: Content) -> some View {
        content
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05),
                value: animate
            )
    }
}

extension View {
    func staggeredAppear(index: Int, animate: Bool) -> some View {
        modifier(StaggeredAppear(index: index, animate: animate))
    }
}

// MARK: - Haptic Feedback

enum DSHaptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
