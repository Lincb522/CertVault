import SwiftUI
import HiconIcons

struct ErrorView: View {
    let message: String
    var retryAction: (() async -> Void)?

    var body: some View {
        VStack(spacing: DS.spacingLG) {
            HIcon(AppIcon.warning)
                .font(.system(size: 36))
                .foregroundStyle(Color.dsOrange)

            VStack(spacing: DS.spacingSM) {
                Text(L10n.error)
                    .font(.headline)
                    .foregroundStyle(Color.dsText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction {
                Button {
                    Task { await retryAction() }
                } label: {
                    Text(L10n.retry)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.spacing2XL)
                        .padding(.vertical, DS.spacingMD)
                        .background(Color.dsBrand, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
