import SwiftUI

extension WorkspaceTabContainerView {
    /// Pinching in on the trackpad opens the tab overview; pinching out closes it (plan O1).
    var overviewPinch: some Gesture {
        MagnifyGesture()
            .onEnded { value in
                if !appState.showTabOverview, value.magnification < Self.pinchInThreshold, tabStore.hasTabs {
                    appState.showTabOverview = true
                } else if appState.showTabOverview, value.magnification > Self.pinchOutThreshold {
                    appState.showTabOverview = false
                }
            }
    }

    static let pinchInThreshold: CGFloat = 0.8
    static let pinchOutThreshold: CGFloat = 1.25
}
