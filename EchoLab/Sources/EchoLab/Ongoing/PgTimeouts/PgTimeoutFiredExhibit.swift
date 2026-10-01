import SwiftUI

/// Revision 2: where the message goes once a limit has fired, drawn as it stays so it can be seen
/// without running anything. Left: you are on the tab. Right: you were on another tab.
struct PgTimeoutFiredExhibit: View {
    let fired: PgTimeoutsRound.Fired

    private let reason = PgTimeoutReason.statement(seconds: 30, scope: "the statement limit for this connection")

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            panel(title: "You are on Query 1", active: 1, toast: fired.toastHere,
                  caption: fired.toastHere ? "The message in the results area, and a notification." : "The message in the results area, where the grid would be.")
            panel(title: "You are on Query 2 when Query 1 stops", active: 2, toast: fired.toastAway,
                  caption: fired.toastAway ? "A notification says which tab stopped; Show goes there." : "Nothing tells you until you go back to Query 1.")
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    private func panel(title: String, active: Int, toast: Bool, caption: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.labelBold).foregroundStyle(ColorTokens.Text.secondary)
            PgTabStrip(tabs: [PgTab(id: 1, title: "Query 1"), PgTab(id: 2, title: "Query 2")], active: active)
            ZStack(alignment: .topTrailing) {
                VStack(spacing: SpacingTokens.xs) {
                    if active == 1 {
                        PgEditorCard(lines: ["select customer_id, sum(total)", "from orders_2019_2026", "group by 1;"])
                            .frame(height: 90)
                        results
                    } else {
                        PgEditorCard(lines: ["select * from customers", "where country = 'SE';"])
                            .frame(height: 90)
                        VStack(alignment: .leading) {
                            PgGrid(columns: ["id", "name", "country"], rows: [["1", "Ada", "SE"], ["2", "Linus", "SE"]])
                            Spacer(minLength: SpacingTokens.none)
                            PgFooter { PgPill { PgStatusLabel(text: "Ready", color: ColorTokens.Status.success) } }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .workspaceCard()
                    }
                }
                if toast { PgTimeoutToast(reason: reason) }
            }
            Text(caption).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var results: some View {
        let message = PgTimeoutMessage(fired: fired, reason: reason)
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if fired == .footer {
                Text(message.messagesText).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            } else {
                message
            }
            Spacer(minLength: SpacingTokens.none)
            PgFooter(segment: fired == .footer ? "Messages" : "Results") {
                PgPill(tint: ColorTokens.Status.error) {
                    PgStatusLabel(text: fired == .footer ? "Timed out" : "Error", color: ColorTokens.Status.error)
                }
                PgPill { Text("0:30").monospacedDigit() }
            }
        }
        .padding(SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}
