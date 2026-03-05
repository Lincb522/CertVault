import SwiftUI

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
}

// MARK: - View Modifiers

extension View {
    @ViewBuilder
    func cardStyle() -> some View {
        if #available(iOS 26, *) {
            self
                .padding(DS.spacingLG)
                .glassEffect(.regular.tint(.dsSurface.opacity(0.5)), in: .rect(cornerRadius: CGFloat(DS.radiusLG)))
        } else {
            self
                .padding(DS.spacingLG)
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DS.radiusLG))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusLG)
                        .stroke(Color.dsBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.tint(.dsSurface.opacity(0.4)), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.dsBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    func glassInteractive(tint: Color? = nil, cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26, *) {
            let base = Glass.regular.interactive()
            if let tint {
                self.glassEffect(base.tint(tint.opacity(0.3)), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(base, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            let bg = tint?.opacity(0.1) ?? Color.dsSurfaceElevated.opacity(0.5)
            self
                .background(bg, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.dsBorder, lineWidth: 0.5)
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
        self.background { AppBackground() }
    }

    func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dsTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
    }
}
