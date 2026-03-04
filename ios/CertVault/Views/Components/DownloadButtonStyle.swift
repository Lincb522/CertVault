import SwiftUI

struct DownloadButtonStyle: ViewModifier {
    var colors: [Color] = [.dsAccentBlue, .dsAccentPurple]

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .foregroundStyle(.primary)
                .glassEffect(
                    .regular.tint(colors.first ?? .dsAccentBlue).interactive(),
                    in: .rect(cornerRadius: 12)
                )
        } else {
            content
                .foregroundStyle(.white)
                .background(colors.first ?? .dsAccentBlue, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SecondaryButtonStyle: ViewModifier {
    var color: Color = .dsAccentBlue

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .foregroundStyle(color)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .foregroundStyle(color)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
