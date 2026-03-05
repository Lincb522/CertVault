import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 15, paused: false)) { timeline in
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let drift = sin(t * 0.15) * 0.02

                    if isDark {
                        glow(context, center: CGPoint(x: w * (0.2 + drift), y: h * (0.08 + drift * 0.5)), radius: w * 0.6,
                             color: Color(hex: "1E3A5F"), opacity: 0.15)
                        glow(context, center: CGPoint(x: w * (0.8 - drift), y: h * (0.15 - drift * 0.3)), radius: w * 0.5,
                             color: Color(hex: "3B1F6E"), opacity: 0.10)
                        glow(context, center: CGPoint(x: w * (0.5 + drift * 0.5), y: h * (0.6 + drift)), radius: w * 0.7,
                             color: Color(hex: "0F2B3D"), opacity: 0.08)
                    } else {
                        glow(context, center: CGPoint(x: w * (0.15 + drift), y: h * (0.05 + drift * 0.3)), radius: w * 0.5,
                             color: Color(hex: "DBEAFE"), opacity: 0.5)
                        glow(context, center: CGPoint(x: w * (0.85 - drift), y: h * (0.1 - drift * 0.2)), radius: w * 0.45,
                             color: Color(hex: "EDE9FE"), opacity: 0.4)
                        glow(context, center: CGPoint(x: w * (0.5 + drift * 0.5), y: h * (0.5 + drift * 0.5)), radius: w * 0.6,
                             color: Color(hex: "E0F2FE"), opacity: 0.25)
                    }
                }
                .blur(radius: 80)
                .ignoresSafeArea()
                .drawingGroup()
            }
        }
        .ignoresSafeArea()
    }

    private func glow(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.3), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }
}
