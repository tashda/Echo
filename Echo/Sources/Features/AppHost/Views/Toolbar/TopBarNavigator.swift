import SwiftUI

/// A toolbar-centered capsule similar to Xcode's, sized to the available space.
/// Width ≈ 2/3 of the available area between navigation and trailing items, clamped to a sensible range.
/// Height matches `WorkspaceChromeMetrics.toolbarTabBarHeight` to align with circular toolbar icons.
struct TopBarNavigator: View {
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        BreadcrumbNavigator()
            .environmentObject(environmentState)
            .environmentObject(appearanceStore)
    }
}
