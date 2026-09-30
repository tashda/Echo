import SwiftUI

enum WorkspaceChromeMetrics {
    /// Visible height of the rounded chrome (tab base plate / icon menu background).
    static let chromeBackgroundHeight: CGFloat = 28
    /// Total vertical footprint of the tab strip (used for layout spacing).
    static let tabStripTotalHeight: CGFloat = 32
    /// Height of a tab inside the plate (one line: icon and title).
    static let tabHeight: CGFloat = 24
    /// Inset applied above chrome controls to align with the tab strip base plate.
    static let chromeTopInset: CGFloat = (tabStripTotalHeight - chromeBackgroundHeight) / 2
    /// Baseline height used by the toolbar-integrated tab bar accessory.
    /// Actual height is driven by the toolbar reference control and may be larger.
    static let toolbarTabBarHeight: CGFloat = 28
}
