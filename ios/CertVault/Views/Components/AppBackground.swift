import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            (isDark ? Color(hex: "050507") : Color(hex: "F8F9FB"))
                .ignoresSafeArea()

            Canvas { context, size in
                let w = size.width
                let h = size.height

                if isDark {
                    fillGlow(context, center: CGPoint(x: w * 0.15, y: h * 0.1), radius: w * 0.7,
                             color: Color(hex: "1A2D4A"), opacity: 0.8)
                    fillGlow(context, center: CGPoint(x: w * 0.82, y: h * 0.08), radius: w * 0.6,
                             color: Color(hex: "0F2B33"), opacity: 0.7)
                    fillGlow(context, center: CGPoint(x: w * 0.35, y: h * 0.45), radius: w * 0.5,
                             color: Color(hex: "2A1F10"), opacity: 0.5)
                    fillGlow(context, center: CGPoint(x: w * 0.7, y: h * 0.6), radius: w * 0.45,
                             color: Color(hex: "1A0F2E"), opacity: 0.4)
                } else {
                    fillGlow(context, center: CGPoint(x: w * 0.1, y: h * 0.06), radius: w * 0.55,
                             color: Color(hex: "C4D2E8"), opacity: 0.45)
                    fillGlow(context, center: CGPoint(x: w * 0.85, y: h * 0.05), radius: w * 0.5,
                             color: Color(hex: "CEDAEA"), opacity: 0.35)
                    fillGlow(context, center: CGPoint(x: w * 0.35, y: h * 0.35), radius: w * 0.4,
                             color: Color(hex: "D6D0E6"), opacity: 0.3)
                    fillGlow(context, center: CGPoint(x: w * 0.65, y: h * 0.65), radius: w * 0.5,
                             color: Color(hex: "D8E0EC"), opacity: 0.25)
                }
            }
            .padding(-80)
            .blur(radius: 60)
            .ignoresSafeArea()
            .drawingGroup()

            VStack {
                ParallaxMountainHeader(height: 300)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.25),
                                .init(color: .white.opacity(0.5), location: 0.5),
                                .init(color: .white.opacity(0.15), location: 0.75),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isDark ? 0.85 : 0.35)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private func fillGlow(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.3), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }
}

