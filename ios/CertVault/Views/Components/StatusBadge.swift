import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .dsAccent) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    static func forStatus(_ status: String) -> StatusBadge {
        let label = Localized.status(status)
        switch status.uppercased() {
        case "ENABLED", "ACTIVE", "VALID":
            return StatusBadge(label, color: .dsAccent)
        case "DISABLED", "REVOKED", "EXPIRED":
            return StatusBadge(label, color: .dsAccentPink)
        case "PROCESSING", "PENDING":
            return StatusBadge(label, color: .dsAccentOrange)
        default:
            return StatusBadge(label, color: .dsMuted)
        }
    }
}
