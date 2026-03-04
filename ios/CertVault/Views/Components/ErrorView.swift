import SwiftUI
import HiconIcons

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.dsAccentOrange.opacity(0.12))
                    .frame(width: 72, height: 72)
                HIcon(AppIcon.warning)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.dsAccentOrange)
            }

            VStack(spacing: 8) {
                Text("出错了")
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let retry = retryAction {
                Button(action: retry) {
                    HStack(spacing: 6) {
                        HIcon(AppIcon.refresh).font(.caption)
                        Text("重试")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color.dsAccentBlue)
                    .background(Color.dsAccentBlue.opacity(0.12), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
