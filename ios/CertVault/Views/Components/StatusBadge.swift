import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    init(status: String) {
        let badge = DSBadge.forStatus(status)
        self.text = badge.text
        self.color = badge.color
    }

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        DSBadge(text: text, color: color)
    }

    static func forStatus(_ status: String) -> StatusBadge {
        StatusBadge(status: status)
    }
}
