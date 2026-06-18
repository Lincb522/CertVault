import WidgetKit

enum WidgetHelper {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
