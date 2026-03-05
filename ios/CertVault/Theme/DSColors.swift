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

// MARK: - Design System Colors

extension Color {
    // --- Core Surfaces ---
    static let dsBackground = Color(light: Color(hex: "F5F5F7"), dark: Color(hex: "050507"))
    static let dsSurface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "141416"))
    static let dsSurfaceElevated = Color(light: Color(hex: "F0F0F2"), dark: Color(hex: "1C1C1F"))

    // --- Text ---
    static let dsText = Color(light: Color(hex: "111113"), dark: Color(hex: "F5F5F7"))
    static let dsTextSecondary = Color(light: Color(hex: "6B6B76"), dark: Color(hex: "9898A5"))
    static let dsTextTertiary = Color(light: Color(hex: "A0A0AD"), dark: Color(hex: "606070"))

    // --- Borders ---
    static let dsBorder = Color(light: Color(hex: "E2E2E8"), dark: Color(hex: "232328"))
    static let dsDivider = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.06))

    // --- Accent Palette (high saturation) ---
    static let dsBlue = Color(light: Color(hex: "2563EB"), dark: Color(hex: "4F8FFF"))
    static let dsGreen = Color(light: Color(hex: "16A34A"), dark: Color(hex: "34D572"))
    static let dsPurple = Color(light: Color(hex: "7C3AED"), dark: Color(hex: "A78BFA"))
    static let dsOrange = Color(light: Color(hex: "EA580C"), dark: Color(hex: "FB923C"))
    static let dsCyan = Color(light: Color(hex: "0891B2"), dark: Color(hex: "22D3EE"))
    static let dsPink = Color(light: Color(hex: "DB2777"), dark: Color(hex: "F472B6"))
    static let dsRed = Color(light: Color(hex: "DC2626"), dark: Color(hex: "F87171"))

    // --- Semantic ---
    static let dsBrand = dsBlue
    static let dsSuccess = dsGreen
    static let dsWarning = dsOrange
    static let dsDanger = dsRed

    // --- Gradients (on Color for ShapeStyle contexts) ---
    static var dsBrandGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "4F8FFF"), Color(hex: "A78BFA")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var dsGradientBlue: LinearGradient {
        LinearGradient(colors: [Color(hex: "2563EB"), Color(hex: "06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var dsGradientPurple: LinearGradient {
        LinearGradient(colors: [Color(hex: "7C3AED"), Color(hex: "DB2777")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var dsGradientGreen: LinearGradient {
        LinearGradient(colors: [Color(hex: "16A34A"), Color(hex: "06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var dsGradientOrange: LinearGradient {
        LinearGradient(colors: [Color(hex: "EA580C"), Color(hex: "FACC15")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var dsGradientPink: LinearGradient {
        LinearGradient(colors: [Color(hex: "EC4899"), Color(hex: "A78BFA")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var dsGradientCyan: LinearGradient {
        LinearGradient(colors: [Color(hex: "06B6D4"), Color(hex: "3B82F6")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // --- Backward Compatibility (old names → new) ---
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
    static var greenGradient: LinearGradient { dsGradientGreen }
}

// MARK: - LinearGradient Convenience (allows .dsGradientBlue in gradient: parameter contexts)

extension LinearGradient {
    static var dsBrandGradient: LinearGradient { Color.dsBrandGradient }
    static var dsGradientBlue: LinearGradient { Color.dsGradientBlue }
    static var dsGradientPurple: LinearGradient { Color.dsGradientPurple }
    static var dsGradientGreen: LinearGradient { Color.dsGradientGreen }
    static var dsGradientOrange: LinearGradient { Color.dsGradientOrange }
    static var dsGradientPink: LinearGradient { Color.dsGradientPink }
    static var dsGradientCyan: LinearGradient { Color.dsGradientCyan }
}
