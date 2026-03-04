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
        switch status.uppercased() {
        case "ENABLED", "ACTIVE", "VALID":
            return StatusBadge(status, color: .dsAccent)
        case "DISABLED", "REVOKED", "EXPIRED":
            return StatusBadge(status, color: .dsAccentPink)
        case "PROCESSING", "PENDING":
            return StatusBadge(status, color: .dsAccentOrange)
        default:
            return StatusBadge(status, color: .dsMuted)
        }
    }
}
