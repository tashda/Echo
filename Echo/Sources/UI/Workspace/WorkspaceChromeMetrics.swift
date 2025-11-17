import SwiftUI

enum WorkspaceChromeMetrics {
    /// Visible height of the rounded chrome (tab base plate / icon menu background).
    static let chromeBackgroundHeight: CGFloat = 28
    /// Total vertical footprint of the tab strip (used for layout spacing).
    static let tabStripTotalHeight: CGFloat = 38
    /// Inset applied above chrome controls to align with the tab strip base plate.
    static let chromeTopInset: CGFloat = (tabStripTotalHeight - chromeBackgroundHeight) / 2
    /// Height used by the toolbar-integrated tab bar accessory.
    static let toolbarTabBarHeight: CGFloat = 28
}
