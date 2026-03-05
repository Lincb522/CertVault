import SwiftUI
import HiconIcons

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.spacingXL) {
            ZStack {
                Circle()
                    .fill(Color.dsWarning.opacity(0.12))
                    .frame(width: 72, height: 72)
                HIcon(AppIcon.warning)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.dsWarning)
            }

            VStack(spacing: DS.spacingSM) {
                Text(L10n.error)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.spacing2XL)
            }

            if let retry = retryAction {
                Button(action: retry) {
                    HStack(spacing: 6) {
                        HIcon(AppIcon.refresh).font(.caption)
                        Text(L10n.retry)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, DS.spacing2XL)
                    .padding(.vertical, DS.spacingMD)
                    .foregroundStyle(.white)
                    .background(Color.dsBrandGradient, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
