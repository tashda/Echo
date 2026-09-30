import SwiftUI

/// Toasts and the notification history as they are in Echo today (plan Phase 5, round 15).
@MainActor
enum NotificationsArea {
    static let area = LabArea(
        id: "notifications",
        title: "Notifications",
        symbol: "bell",
        summary: "Toasts stack at the top right of the first card. The bell opens the history in the inspector's column.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "Round 15's history-in-the-column was built in commit 755f8254 and awaits your confirmation in the running app."),
            stageHeight: 640,
            behaviours: [
                .init(trigger: "An event happens", result: "A toast appears at the top right of the tab's first card, below the tab bar."),
                .init(trigger: "Up to three", result: "They stack and melt together."),
                .init(trigger: "Hover a toast", result: "Pauses it and expands it into a card with the full message and actions (Retry, Show details, Open tab)."),
                .init(trigger: "The same event repeats", result: "It collapses to “×3”."),
                .init(trigger: "An error", result: "It stays until dismissed."),
                .init(trigger: "Click the bell", result: "The history opens in the inspector's column: a server's events per box, a filter menu and Clear, kept across launches."),
                .init(trigger: "Click a history row", result: "It opens in place to the whole message, selectable, with Copy and a link to its tab or server."),
                .init(trigger: "Muted toast", result: "Every event is still recorded in history."),
            ],
            motions: [
                .init(name: "Toasts stack and expand", curve: "house spring", duration: "0.45s"),
                .init(name: "Column switches between inspector and history", curve: "house spring", duration: "0.45s"),
            ],
            measurements: [
                .init(label: "Toast width", value: "320pt, collapsed or expanded", token: "LabRound15NoticeMetrics"),
                .init(label: "Toast actions", value: "quiet text links"),
                .init(label: "Placement", value: "inside the first card, inset from its edges"),
                .init(label: "Material", value: "Liquid Glass", token: "floating controls"),
            ],
            rules: [
                .init(text: "History opens in the inspector's column",
                      why: "It is the same card and grouped boxes, with room for long messages. A popover under the bell was too small; a notifications tab was not chosen.",
                      rounds: ["ported.Round 15 · notifications"]),
                .init(text: "Toasts sit at the top right, not bottom centre",
                      why: "Bottom-centre toasts were rejected; the corner never covers the editor's caret line.",
                      rounds: ["decided.toasts-and-notifications"]),
                .init(text: "Glass for the toasts",
                      why: "They are floating controls, so glass is allowed.",
                      rounds: ["decided.toasts-and-notifications"]),
            ],
            code: [
                "Echo/Sources/Features/AppHost/Views/Notifications/",
                "Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/NotificationBellToolbarButton.swift",
            ]
        ) {
            LabNoticeWindow(center: LabNoticeCenter(), style: .drawer, top: .belowTabBar, showsInspector: false)
                .padding(SpacingTokens.lg)
        }
    )
}
