import SwiftUI

/// A reusable back/forward segmented control for toolbars.
///
/// Uses closures so each view decides what "navigating back" means —
/// whether that's a single selection, a composite state with sub-tabs, etc.
///
/// Usage:
/// ```swift
/// .toolbar {
///     ToolbarItem(placement: .navigation) {
///         ToolbarNavigationButtons(
///             canGoBack: history.canGoBack,
///             canGoForward: history.canGoForward,
///             onBack: { /* restore state from history.goBack(...) */ },
///             onForward: { /* restore state from history.goForward(...) */ }
///         )
///     }
/// }
/// ```
struct ToolbarNavigationButtons: View {

    var canGoBack: Bool
    var canGoForward: Bool
    var onBack: () -> Void
    var onForward: () -> Void

    var body: some View {
        ControlGroup {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(!canGoBack)

            Button(action: onForward) {
                Label("Forward", systemImage: "chevron.right")
            }
            .disabled(!canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}
