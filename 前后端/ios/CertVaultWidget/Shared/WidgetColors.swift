import SwiftUI

extension Color {
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

enum WColor {
    static let background = Color(light: Color(hex: "F8F9FB"), dark: Color(hex: "050507"))
    static let surface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1E293B"))
    static let accent = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let accentBlue = Color(red: 0.24, green: 0.51, blue: 0.96)
    static let accentOrange = Color(red: 0.96, green: 0.62, blue: 0.14)
    static let accentPurple = Color(red: 0.56, green: 0.40, blue: 0.96)
    static let accentPink = Color(red: 0.93, green: 0.30, blue: 0.56)
    static let accentCyan = Color(red: 0.06, green: 0.82, blue: 0.84)
    static let text = Color(light: Color(hex: "1E293B"), dark: Color(hex: "F8FAFC"))
    static let muted = Color(light: Color(hex: "64748B"), dark: Color(hex: "94A3B8"))
    static let border = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
