import SwiftUI

// MARK: - Design System Tokens

enum DS {
    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacing2XL: CGFloat = 24
    static let spacing3XL: CGFloat = 32

    // MARK: - Radius
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusXXL: CGFloat = 24

    // MARK: - Shadows
    static func shadowSM(_ scheme: ColorScheme = .light) -> some ShapeStyle {
        Color.black.opacity(scheme == .dark ? 0.3 : 0.06)
    }

    // MARK: - Icon Size
    static let iconSM: CGFloat = 20
    static let iconMD: CGFloat = 24
    static let iconLG: CGFloat = 32

    // MARK: - Touch Target
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Font Tokens

extension Font {
    static let dsMono = Font.system(.caption, design: .monospaced)
    static let dsMonoSmall = Font.system(.caption2, design: .monospaced)
    static let dsStatLarge = Font.system(size: 34, weight: .bold, design: .rounded)
}
