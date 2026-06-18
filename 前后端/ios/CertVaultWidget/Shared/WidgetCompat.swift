import SwiftUI
import WidgetKit

extension View {
    @ViewBuilder
    func widgetContainerBackground(_ background: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}
