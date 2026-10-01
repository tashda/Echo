import Observation
import SwiftUI

/// Toasts and the notification history as they are in Echo today (plan Phase 7, round 15).
@MainActor
enum NotificationsArea {
    private static let state = NotificationsSpecimenState()

    static let area = LabArea(
        id: "notifications",
        title: "Notifications",
        symbol: "bell",
        summary: "Toasts stack at the top right of the tab's first card. The bell opens the history in the inspector's column.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "d4659ef6", date: "2026-09-30",
                note: "Read from StatusToastRow, StatusToastStack, StatusToastPresenter, ToastOverlay, NotificationHistoryPanel and Card, NotificationBellToolbarButton, NotificationEngine (+LongQuery), NotificationEvent, NotificationHistory, NotificationRecord, OperationFinishNotifier, AppState and the Toast and Inspector tokens. 2026-10-01: checked the commits since d4659ef6 (toast buttons 6pt under the text, the long-query banner, notification actions, round 34's bell spinner and finish notices). The specimen copies them."),
            stageHeight: 560,
            behaviours: [
                .init(trigger: "An event happens", result: "A toast appears in the top-right corner of the tab's first card (inside the editor card on a query tab), below the tab bar and left of the inspector."),
                .init(trigger: "More events", result: "Up to three stack, newest on top, and melt together; the fourth pushes the oldest out."),
                .init(trigger: "The same event again", result: "It counts up (×2, ×3) and moves to the top instead of stacking."),
                .init(trigger: "Hover a toast", result: "It stays while hovered and opens in place to the whole reason, selectable, with small buttons (Open Tab or Show Server, Copy, Show All) and ×."),
                .init(trigger: "An error", result: "It stays until dismissed; its × always shows."),
                .init(trigger: "Other toasts", result: "They go after 3 seconds; 5 for connection failures, database switch failures and job errors. A hovered toast waits until the pointer leaves."),
                .init(trigger: "Delivery setting", result: "Each category can be off, and delivery is an in-app toast, a native macOS notification, or both. History records the event either way."),
                .init(trigger: "Click the bell", result: "The history takes the inspector's column; the badge clears. Click again to put it away."),
                .init(trigger: "A long query ends while Echo isn't in front", result: "30 s or more: a macOS banner, \"Query 1 finished in 1:12\" or \"… failed after 1:12\", whatever the delivery setting (round 20)."),
                .init(trigger: "A long operation ends", result: "Its own notification says so. One of 5 s or more that posted nothing gets \"Backup shop finished in 1:12\" or \"Backup shop failed: reason\" (round 34)."),
                .init(trigger: "A notification with an action", result: "Its toast and history card add Reconnect or Go to Error while it still applies."),
                .init(trigger: "A long operation runs", result: "After a second a small spinner sits on the bell and its tooltip names the operation; query runs show only on Run (round 34)."),
                .init(trigger: "Click the inspector button", result: "From the history it switches the column to the details."),
                .init(trigger: "The history", result: "Compact cards grouped Today, Yesterday, then by date: an icon, the message's first part and the time on one line. What was new when the bell opened is bold and counted beside the title."),
                .init(trigger: "Click a card", result: "It fades open to the server, the rest of the message (selectable) and small Open Tab or Show Server and Copy buttons."),
                .init(trigger: "The ⋯ menu", result: "Filters (All, Errors, Connection, Queries, Jobs) and Clear All."),
                .init(trigger: "Muted toast", result: "Every event is still recorded in history (500 kept, across launches)."),
                .init(trigger: "A query fails", result: "Recorded in history; a toast only when its tab isn't in front (the results card shows the error)."),
                .init(trigger: "Bell while the details show, then the bell again", result: "The column switches to the history, then closes; it never falls back to the details. The inspector button (⌥⌘I) from the history switches to the details, otherwise it shows or hides the column."),
                .init(trigger: "A toast's text", result: "A bold title (the message up to its first \": \") with the reason under it in two lines of secondary text."),
                .init(trigger: "Flick a toast to the right", result: "It follows the pointer and fades; past 80pt it goes, otherwise it springs back."),
            ],
            motions: [
                .init(name: "Toast in and out", curve: "house spring", duration: "0.45s", note: "Slides from the top and fades"),
                .init(name: "Toast opens on hover", curve: "house spring", duration: "0.45s"),
                .init(name: "Column out", curve: "house spring", duration: "0.45s", note: "Like the tree"),
                .init(name: "Column back", curve: "settle, no overshoot", duration: "0.45s"),
                .init(name: "History and details", curve: "cross-fade", duration: "0.45s"),
            ],
            measurements: [
                .init(label: "Toast width", value: "320pt, collapsed or expanded", token: "LayoutTokens.Toast.width"),
                .init(label: "Toast corners", value: "18pt", token: "LayoutTokens.Toast.cornerRadius"),
                .init(label: "Inset from the card", value: "8pt", token: "LayoutTokens.Toast.inset"),
                .init(label: "Toasts at once", value: "3", token: "StatusToastPresenter.maximumVisible"),
                .init(label: "Toast duration", value: "3s; errors stay", token: "NotificationEngine.post duration"),
                .init(label: "Toast actions", value: "Small bordered buttons", token: ".bordered, .small"),
                .init(label: "Column width", value: "300pt (260 to 640)", token: "LayoutTokens.Inspector"),
                .init(label: "Bell badge", value: "the system badge with the unread count", token: ".badge(unreadCount)"),
                .init(label: "History cards", value: "One line; 12pt sides, 8pt top and bottom, 6pt apart, 10pt corners", token: "LayoutTokens.FloatingSurface.rowCornerRadius"),
                .init(label: "History actions", value: "Small bordered buttons", token: ".bordered, .small"),
                .init(label: "History kept", value: "500 events", token: "NotificationHistory.capacity"),
                .init(label: "Material", value: "Liquid Glass for toasts; the column is an opaque card"),
            ],
            rules: [
                .init(text: "History opens in the inspector's column",
                      why: "It is the same card and grouped boxes, with room for long messages. A popover under the bell was too small; a notifications tab was not chosen.",
                      rounds: ["ported.Round 15 · notifications"]),
                .init(text: "The history is compact cards by day",
                      why: "Cards read as separate events; one line each keeps them calm, and nothing is said twice. The count sits quietly beside the title and Clear lives in the ⋯ menu, because accent text in the header looked odd (round 17).",
                      rounds: ["ongoing.notification-history-r17"]),
                .init(text: "Toasts sit inside the first card's top-right corner",
                      why: "Below the tab bar and inside the editor card, so they never cross a card's edge or hide under the inspector (round 15).",
                      rounds: ["ported.Round 15 · notifications"]),
                .init(text: "Toasts keep one width",
                      why: "Hovering opens them downwards only, so nothing jumps sideways.",
                      rounds: ["ported.Round 15 · notifications"]),
                .init(text: "Glass for the toasts",
                      why: "They are floating controls, so glass is allowed.",
                      rounds: ["decided.toasts-and-notifications"]),
                .init(text: "A toast is a title with its reason, small buttons, and a flick to dismiss",
                      why: "The reason of a failure reads without hovering, the buttons match the history, and dismissing works like a macOS banner (round 18).",
                      rounds: ["ongoing.notification-toast-r18"]),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Notifications/",
                "Echo/Sources/Features/AppHost/Domain/State/StatusToastPresenter.swift",
                "Echo/Sources/Shared/Notifications/",
                "Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/NotificationBellToolbarButton.swift",
                "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceInspectorColumn.swift",
                "Echo/Sources/Features/AppHost/Views/Notifications/StatusToastRow.swift",
            ]
        ) {
            NotificationsSpecimen(state: state)
        }
        .controls {
            NotificationsControls(state: state)
        },
        spec: NotificationsSpec.spec(stageHeight: 560, specimen: { NotificationsSpecimen(state: state) }, controls: { NotificationsControls(state: state) }).onState { state.force($0) }
    )
}

private struct NotificationsControls: View {
    let state: NotificationsSpecimenState

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            Button("Post") { state.post() }
            Button("Post the same again") { state.repeatLatest() }
            Button(state.column == .history ? "Close the history" : "Open the bell") { state.toggleHistory() }
            Button(state.column == .details ? "Hide the inspector" : "Show the inspector") { state.toggleInspector() }
            Text("Hover a toast to open it; errors stay until dismissed.")
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
        }
    }
}
