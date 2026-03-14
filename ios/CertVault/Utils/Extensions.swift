import SwiftUI

// MARK: - Color Hex Init

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

// MARK: - Design System Colors (adaptive light/dark)

extension Color {
    static let dsBackground = Color(light: Color(hex: "F8F9FB"), dark: Color(hex: "050507"))
    static let dsSurface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1E293B"))
    static let dsSurfaceLight = Color(light: Color(hex: "F1F5F9"), dark: Color(hex: "334155"))
    static let dsAccent = Color(red: 0.13, green: 0.77, blue: 0.37)         // #22C55E
    static let dsAccentBlue = Color(red: 0.24, green: 0.51, blue: 0.96)     // #3B82F6
    static let dsAccentOrange = Color(red: 0.96, green: 0.62, blue: 0.14)   // #F59E23
    static let dsAccentPurple = Color(red: 0.56, green: 0.40, blue: 0.96)   // #8B5CF6
    static let dsAccentCyan = Color(red: 0.06, green: 0.82, blue: 0.84)     // #0ED1D6
    static let dsAccentPink = Color(red: 0.93, green: 0.30, blue: 0.56)     // #EC4899
    static let dsText = Color(light: Color(hex: "1E293B"), dark: Color(hex: "F8FAFC"))
    static let dsMuted = Color(light: Color(hex: "64748B"), dark: Color(hex: "94A3B8"))
    static let dsBorder = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))

    static let accentGradientStart = Color.dsAccentBlue
    static let accentGradientEnd = Color.dsAccentPurple

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [.dsAccentBlue, .dsAccentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var greenGradient: LinearGradient {
        LinearGradient(
            colors: [.dsAccent, Color(red: 0.10, green: 0.60, blue: 0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Date

extension Date {
    var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: .now)
    }

    var shortDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }

    var fullDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: self)
    }
}

// MARK: - String

extension String {
    var maskedMiddle: String {
        guard count > 8 else { return self }
        let prefix = self.prefix(4)
        let suffix = self.suffix(4)
        return "\(prefix)****\(suffix)"
    }

    func truncated(_ maxLength: Int = 20) -> String {
        count <= maxLength ? self : String(prefix(maxLength)) + "…"
    }

    /// Parse an ISO 8601 date string (UTC) and format to local timezone.
    /// `style`: `.short` → "yyyy-MM-dd", `.full` → "yyyy-MM-dd HH:mm", `.dateOnly` → "MM-dd"
    func toLocalDate(_ style: LocalDateStyle = .full) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: self) ?? {
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: self)
        }() ?? {
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            fallback.timeZone = TimeZone(identifier: "UTC")
            return fallback.date(from: self)
        }()
        guard let date else {
            return String(prefix(16)).replacingOccurrences(of: "T", with: " ")
        }
        let out = DateFormatter()
        out.timeZone = .current
        switch style {
        case .short: out.dateFormat = "yyyy-MM-dd"
        case .full: out.dateFormat = "yyyy-MM-dd HH:mm"
        case .long: out.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return out.string(from: date)
    }
}

enum LocalDateStyle { case short, full, long }

// MARK: - View Modifiers

extension View {
    @ViewBuilder
    func cardStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            self
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    func glassInteractive(tint: Color? = nil, cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26, *) {
            let base = Glass.regular.interactive()
            if let tint {
                self.glassEffect(base.tint(tint.opacity(0.2)), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(base, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.dsBorder.opacity(0.5), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    func shimmer(_ active: Bool) -> some View {
        if active {
            self.redacted(reason: .placeholder)
        } else {
            self
        }
    }

    func pageBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { AppBackground().ignoresSafeArea(.all) }
    }

    @ViewBuilder
    func sheetStyle() -> some View {
        self
            .presentationCornerRadius(24)
            .presentationDragIndicator(.visible)
    }

    func clearFormBackground() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

extension View {
    func glassSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
        }
    }

    func glassSheet<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        self.sheet(item: item) { val in
            content(val)
                .presentationCornerRadius(24)
                .presentationDragIndicator(.visible)
        }
    }

    func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dsMuted)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
    }

    func sheetNavStyle() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
