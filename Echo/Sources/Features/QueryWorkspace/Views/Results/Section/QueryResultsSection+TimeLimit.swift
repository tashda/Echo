import SwiftUI

/// Round 21, timeouts (TF4): a statement the time limit stopped, explained where its result would
/// be, with Run Without Limit and the setting it came from.
struct QueryTimeLimitStopView: View {
    let stop: QueryTimeLimitStop
    let query: QueryEditorState
    let connectionID: UUID

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "timer")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Status.error)
            Text(stop.explanation)
                .font(TypographyTokens.standard)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: SpacingTokens.xs) {
                Button("Run Without Limit") {
                    query.runWithoutLimitOnce = true
                    query.rerunAction?()
                }
                settingsButton
            }
            .controlSize(.small)
            Text(query.transactionState == .none
                 ? "Nothing was changed: the statement was rolled back."
                 : "The transaction now needs ROLLBACK.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(SpacingTokens.lg)
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var settingsButton: some View {
        #if os(macOS)
        switch stop.scope {
        case .connection:
            Button("Connection Settings…") {
                ManageConnectionsWindowController.shared.present(selectedConnectionID: connectionID)
            }
        case .settings:
            Button("Settings…") { openWindow(id: SettingsWindowScene.sceneID) }
        case .server:
            EmptyView()
        }
        #endif
    }
}
