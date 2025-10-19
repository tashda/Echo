import SwiftUI

extension WorkspaceTabBarStyle {
    var chromeTopPadding: CGFloat {
        switch self {
        case .floating:
            return WorkspaceChromeMetrics.chromeTopInset
        case .toolbarCompact:
            return 0
        }
    }

    var contentVerticalOffset: CGFloat {
        switch self {
        case .floating:
            return 0
        case .toolbarCompact:
            // Pull content up to sit flush beneath the toolbar when tabs live inside it.
            return -WorkspaceChromeMetrics.tabStripTotalHeight
        }
    }
}
