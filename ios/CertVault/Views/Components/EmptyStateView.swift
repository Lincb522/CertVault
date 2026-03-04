import SwiftUI
import HiconIcons

struct EmptyStateView: View {
    let icon: UIImage
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            iconView
            textContent
            actionButton
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.dsSurfaceLight.opacity(0.4))
                .frame(width: 80, height: 80)
            HIcon(icon)
                .font(.system(size: 32))
                .foregroundStyle(Color.dsMuted.opacity(0.6))
        }
    }

    private var textContent: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.dsText.opacity(0.8))
            if let msg = message {
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(action: action) {
                HStack(spacing: 6) {
                    HIcon(AppIcon.addCircle).font(.caption)
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundStyle(Color.dsAccent)
                .background(Color.dsAccent.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.dsAccent.opacity(0.3), lineWidth: 1))
            }
            .padding(.top, 4)
        }
    }
}
