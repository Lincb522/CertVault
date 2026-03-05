import SwiftUI

struct LoadingView: View {
    var message: String = L10n.loading

    @State private var dotCount = 0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: DS.spacingLG) {
            ZStack {
                Circle()
                    .stroke(Color.dsBorder, lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(colors: [Color.dsBrand, Color.dsBrand.opacity(0.1)], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(scale == 1 ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: scale)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            scale = 1
        }
    }
}
