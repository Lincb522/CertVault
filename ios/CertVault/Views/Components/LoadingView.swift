import SwiftUI

struct LoadingView: View {
    var message: String = "加载中..."

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.dsAccentBlue)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.dsMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
