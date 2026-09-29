import SwiftUI

/// The workspace's top-trailing corner: the history card under the bell and the toasts. Placed in
/// the content's safe area, so it sits one gutter below the toolbar whatever its height.
struct NotificationOverlay: ViewModifier {
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                StatusToastStack(presenter: environmentState.toastPresenter) {
                    appState.isNotificationHistoryVisible = true
                }
                .padding(SpacingTokens.xs)
                .opacity(appState.isNotificationHistoryVisible ? 0 : 1)
            }
            .floatingCard(
                isPresented: Bindable(appState).isNotificationHistoryVisible,
                insets: EdgeInsets(top: SpacingTokens.xs, leading: 0, bottom: 0, trailing: SpacingTokens.xs)
            ) {
                if let history = environmentState.notificationEngine?.history {
                    NotificationHistoryCard(history: history) { appState.isNotificationHistoryVisible = false }
                }
            }
            .onChange(of: appState.isNotificationHistoryVisible) { _, isVisible in
                if isVisible { environmentState.notificationEngine?.history.markAllRead() }
            }
    }
}

extension View {
    func notificationOverlay() -> some View {
        modifier(NotificationOverlay())
    }
}
