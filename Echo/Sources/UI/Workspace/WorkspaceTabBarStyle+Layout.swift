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
            return -WorkspaceChromeMetrics.toolbarTabBarHeight
        }
    }
}
