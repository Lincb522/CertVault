import SwiftUI
import HiconIcons

struct EmptyStateView: View {
    let icon: UIImage
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        DSEmptyState(icon: icon, title: title, message: message, actionTitle: actionTitle, action: action)
    }
}
