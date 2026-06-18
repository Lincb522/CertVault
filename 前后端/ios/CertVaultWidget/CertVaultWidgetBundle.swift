import WidgetKit
import SwiftUI

@main
struct CertVaultWidgetBundle: WidgetBundle {
    var body: some Widget {
        DashboardWidget()
        ExpiryWidget()
        AccountWidget()
    }
}
