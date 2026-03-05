import SwiftUI

struct LoadingView: View {
    var message: String = "加载中..."

    var body: some View {
        VStack(spacing: DS.spacingXL) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.dsBrand)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
