import SwiftUI

/// The toasts, in the top-trailing corner of the cards area (plan N2): below the tab strip and left
/// of the inspector, so an open inspector never covers them.
struct ToastOverlay: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            StatusToastStack(presenter: environmentState.toastPresenter) {
                appState.isNotificationHistoryVisible = true
            }
            .padding(.top, WorkspaceChromeMetrics.tabStripTotalHeight + SpacingTokens.xs)
            .padding(.trailing, SpacingTokens.xs)
        }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
