import SwiftUI
import HiconIcons

struct GradientButton: View {
    let title: String
    let icon: UIImage?
    let color: Color
    let action: () -> Void

    init(_ title: String, icon: UIImage? = nil,
         gradient: [Color] = [.dsAccentBlue, .dsAccentPurple],
         action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = gradient.first ?? .dsAccentBlue
        self.action = action
    }

    var body: some View {
        if #available(iOS 26, *) {
            glassButton
        } else {
            solidButton
        }
    }

    @available(iOS 26, *)
    private var glassButton: some View {
        Button(action: action) {
            buttonContent
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glass)
        .tint(color)
    }

    private var solidButton: some View {
        Button(action: action) {
            buttonContent
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonContent: some View {
        HStack(spacing: 8) {
            if let icon {
                HIcon(icon).font(.body)
            }
            Text(title)
                .fontWeight(.semibold)
        }
    }
}
