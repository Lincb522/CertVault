import SwiftUI

// MARK: - Adaptive Color Init

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Zinc-based Design System Colors

extension Color {
    // --- Core Surfaces ---
    static let dsBackground = Color(light: Color(hex: "FAFAFA"), dark: Color(hex: "09090B"))
    static let dsSurface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "18181B"))
    static let dsSurfaceElevated = Color(light: Color(hex: "F4F4F5"), dark: Color(hex: "27272A"))

    // --- Text ---
    static let dsText = Color(light: Color(hex: "18181B"), dark: Color(hex: "FAFAFA"))
    static let dsTextSecondary = Color(light: Color(hex: "71717A"), dark: Color(hex: "A1A1AA"))
    static let dsTextTertiary = Color(light: Color(hex: "A1A1AA"), dark: Color(hex: "71717A"))

    // --- Borders ---
    static let dsBorder = Color(light: Color(hex: "E4E4E7"), dark: Color(hex: "27272A"))
    static let dsDivider = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.06))

    // --- Accent Palette ---
    static let dsBlue = Color(light: Color(hex: "2563EB"), dark: Color(hex: "3B82F6"))
    static let dsGreen = Color(light: Color(hex: "16A34A"), dark: Color(hex: "22C55E"))
    static let dsPurple = Color(light: Color(hex: "7C3AED"), dark: Color(hex: "8B5CF6"))
    static let dsOrange = Color(light: Color(hex: "D97706"), dark: Color(hex: "F59E0B"))
    static let dsCyan = Color(light: Color(hex: "0891B2"), dark: Color(hex: "06B6D4"))
    static let dsPink = Color(light: Color(hex: "DB2777"), dark: Color(hex: "EC4899"))
    static let dsRed = Color(light: Color(hex: "DC2626"), dark: Color(hex: "EF4444"))

    // --- Semantic ---
    static let dsBrand = dsBlue
    static let dsSuccess = dsGreen
    static let dsWarning = dsOrange
    static let dsDanger = dsRed

    // --- Gradients ---
    static var dsBrandGradient: LinearGradient {
        LinearGradient(colors: [.dsBlue, .dsPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // --- Backward Compatibility (old names → new values) ---
    static let dsSurfaceLight = dsSurfaceElevated
    static let dsMuted = dsTextSecondary
    static let dsAccent = dsGreen
    static let dsAccentBlue = dsBlue
    static let dsAccentPurple = dsPurple
    static let dsAccentOrange = dsOrange
    static let dsAccentCyan = dsCyan
    static let dsAccentPink = dsPink
    static let accentGradientStart = dsBlue
    static let accentGradientEnd = dsPurple
    static var accentGradient: LinearGradient { dsBrandGradient }
    static var greenGradient: LinearGradient {
        LinearGradient(colors: [.dsGreen, Color(hex: "059669")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
