import SwiftUI

extension WorkspaceTabContainerView {
    /// Pinching in on the trackpad opens the tab overview, the ⌘K palette on this window's tabs
    /// (round 35.1); Esc or a click outside closes it.
    var overviewPinch: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                if !appState.isTabOverviewVisible, value.magnification < Self.pinchInThreshold, tabStore.hasTabs {
                    appState.toggleTabOverview()
                }
            }
    }

    static let pinchInThreshold: CGFloat = 0.8
}
