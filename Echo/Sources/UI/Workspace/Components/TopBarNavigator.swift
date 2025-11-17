import SwiftUI

/// A toolbar-centered capsule similar to Xcode's, sized to the available space.
/// Width = 3/5 of available area between navigation and trailing items, clamped to [350, 800].
/// Height matches `WorkspaceChromeMetrics.toolbarTabBarHeight` to align with circular toolbar icons.
struct TopBarNavigator: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NativeBreadcrumbNavigator()
            .environmentObject(appModel)
            .environmentObject(themeManager)
    }
}
