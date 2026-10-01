import SwiftUI

/// Notifications by piece, each with a stable ID (`NTF-1.2`): the toast, the stack, the history
/// and the bell. Values come from `LayoutTokens.Toast`, `StatusToastPresenter` and the history.
@MainActor
enum NotificationsSpec {
    private static let views = "Echo/Sources/Features/AppHost/Views/Notifications/"
    private static let presenter = "Echo/Sources/Features/AppHost/Domain/State/StatusToastPresenter.swift"
    private static let bell = "Echo/Sources/Features/AppHost/Views/Toolbar/WorkspaceToolbarItems/NotificationBellToolbarButton.swift"
    private static let column = "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceInspectorColumn.swift"
    private static let r15 = "ported.Round 15 · notifications"
    private static let r17 = "ongoing.notification-history-r17"
    private static let r18 = "ongoing.notification-toast-r18"

    static func spec<Specimen: View, Controls: View>(
        stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen, @ViewBuilder controls: @escaping () -> Controls
    ) -> AreaSpec {
        AreaSpec(code: "NTF", stageHeight: stageHeight, parts: parts, specimen: specimen).controls(controls)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Toast", summary: "One notification, floating in the corner (round 18).", elements: [
            SpecElement(number: "1.1", name: "Toast", summary: "A title with its reason under it, on glass.", states: [SpecState(key: "toast", name: "Toast showing")], defaultState: "toast", groups: [
                .material(.row("Glass", "Liquid Glass, interactive", token: "glassEffect(.regular.interactive())"),
                          .row("Why glass", "toasts are floating controls, so glass is allowed")),
                .layout(.row("Width", "320pt, collapsed or expanded", token: "LayoutTokens.Toast.width"),
                        .row("Corner", "18pt continuous", token: "LayoutTokens.Toast.cornerRadius"),
                        .row("Padding", "12pt horizontal, 8pt vertical", token: "SpacingTokens.sm / xs")),
            ], rounds: ["decided.toasts-and-notifications", r18], files: [views]),
            SpecElement(number: "1.2", name: "Title", summary: "The message up to its first \": \".", states: [SpecState(key: "toast", name: "Toast showing")], defaultState: "toast", groups: [
                .type(.row("Font", "13pt semibold", token: "TypographyTokens.standard"), .row("Lines", "1")),
                .layout(.row("Icon", "13pt semibold in the event's colour, before the title")),
            ], rounds: [r18], files: [views]),
            SpecElement(number: "1.3", name: "Reason", summary: "What follows the colon, under the title.", states: [SpecState(key: "toastOpen", name: "Toast hovered open")], defaultState: "toastOpen", groups: [
                .type(.row("Font", "11pt secondary", token: "TypographyTokens.detail"), .row("Lines", "2; the whole reason once the toast is hovered")),
                .behaviour(.row("Selectable", "yes, when opened")),
            ], rounds: [r18], files: [views]),
            SpecElement(number: "1.4", name: "Buttons", summary: "Shown when the toast is hovered: Open Tab or Show Server, Copy, Show All.", states: [SpecState(key: "toastOpen", name: "Toast hovered open")], defaultState: "toastOpen", groups: [
                .layout(.row("Style", "small bordered buttons, the same as the history's", token: ".bordered, .small"),
                        .row("Indent", "24pt, under the title", token: "SpacingTokens.lg"),
                        .row("Gap", "6pt under the text", token: "SpacingTokens.xxs2")),
                .behaviour(.row("Action", "a notification can carry one more button while it still applies: Reconnect (a lost PostgreSQL connection) or Go to Error (a failed query)", token: "NotificationAction")),
                .motion(.row("Opens", "house spring, 0.45s: the toast grows downwards only, so nothing jumps sideways")),
            ], rounds: [r18, r15], files: [views]),
            SpecElement(number: "1.5", name: "Dismissing", summary: "A flick to the right, or ×.", states: [SpecState(key: "toastOpen", name: "Toast hovered open")], defaultState: "toastOpen", groups: [
                .behaviour(.row("Flick right", "the toast follows the pointer and fades; past 80pt it goes, otherwise it springs back",
                                token: "LayoutTokens.Toast.swipeDismissDistance / swipeFadeLimit"),
                           .row("×", "shows while hovered; always on an error")),
            ], rounds: [r18], files: [views]),
            SpecElement(number: "1.6", name: "Count", summary: "The same event again counts up.", states: [SpecState(key: "toast", name: "Toast showing")], defaultState: "toast", groups: [
                .type(.row("Label", "×2, ×3 in 11pt semibold, secondary, tabular digits")),
                .behaviour(.row("Repeat", "the toast moves to the top instead of stacking")),
            ], files: [presenter]),
        ]),
        SpecPart(number: "2", name: "Stack", summary: "Where toasts sit and how long they stay.", elements: [
            SpecElement(number: "2.1", name: "Placement and stack", summary: "The top-right corner of the tab's first card, below the tab bar.", states: [SpecState(key: "toast", name: "Toast showing")], defaultState: "toast", groups: [
                .layout(.row("Inset", "8pt from the card's edges", token: "LayoutTokens.Toast.inset"),
                        .row("Inside", "the editor card on a query tab; left of the inspector"),
                        .row("At once", "3, newest on top; a fourth pushes the oldest out", token: "StatusToastPresenter.maximumVisible")),
                .material(.row("Glass", "one GlassEffectContainer, so the toasts melt together")),
                .motion(.row("In and out", "house spring, 0.45s: slides from the top and fades")),
            ], rounds: [r15], files: [presenter, views]),
            SpecElement(number: "2.2", name: "Timing", summary: "How long a toast stays.", states: [SpecState(key: "toast", name: "Toast showing")], defaultState: "toast", groups: [
                .behaviour(.row("Most toasts", "3 seconds", token: "NotificationEngine.post duration"), .row("Connection failures, database switch failures, job errors", "5 seconds", token: "NotificationEvent.duration"),
                           .row("Errors", "until dismissed", token: "Toast.staysUntilDismissed"), .row("Hovered", "waits until the pointer leaves"),
                           .row("A query fails", "a toast only when its tab isn't in front; the results card shows the error"),
                           .row("Delivery", "each category can be off; delivery is an in-app toast, a native macOS notification, or both", token: "NotificationDelivery"),
                           .row("A long query", "30 s or more, ending while Echo isn't in front: a macOS banner whatever the delivery setting (\"Query 1 finished in 1:12\"); a success is also recorded", token: "LongQueryNotice.threshold"),
                           .row("A long operation", "5 s or more on the bell that posted nothing of its own within 2 s of its end: \"Backup shop finished in 1:12\" or \"… failed: reason\" (round 34)", token: "OperationFinishNotifier.minimumDuration"),
                           .row("VoiceOver", "each toast is announced")),
            ], rounds: [r18], files: [presenter]),
        ]),
        SpecPart(number: "3", name: "History", summary: "Every event, in the inspector's column.", elements: [
            SpecElement(number: "3.1", name: "Column", summary: "The history takes the inspector's column.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .layout(.row("Width", "300pt (260 to 640)", token: "LayoutTokens.Inspector")),
                .material(.row("Card", "an opaque workspace card")),
                .motion(.row("Out", "house spring, 0.45s, like the tree"), .row("Back", "settle, no overshoot, 0.45s"),
                        .row("History and details", "cross-fade, 0.45s")),
            ], rounds: [r15], files: [column]),
            SpecElement(number: "3.2", name: "Day heading", summary: "Cards are grouped Today, Yesterday, then by date.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .type(.row("Font", "11pt semibold, secondary", token: "TypographyTokens.detail")),
            ], rounds: [r17], files: [views]),
            SpecElement(number: "3.3", name: "Header", summary: "The title, with what is new counted beside it.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .type(.row("Title", "headline"), .row("Count", "headline, tabular digits, tertiary; only while something is new")),
                .behaviour(.row("Why quiet", "accent text in the header looked odd; Clear lives in the ⋯ menu")),
            ], rounds: [r17], files: [views]),
            SpecElement(number: "3.4", name: "Menu", summary: "The ⋯ menu.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .behaviour(.row("Show", "an inline picker: All, Errors, Connection, Queries, Jobs; the title becomes, for example, Errors Notifications"),
                           .row("Clear All", "destructive; disabled when the history is empty"), .row("Tooltip", "Filter and Clear"),
                           .row("Empty", "\"No notifications\", or \"No errors notifications\" under a filter")),
            ], rounds: [r17], files: [views]),
            SpecElement(number: "3.5", name: "Card", summary: "One line: an icon, the message's first part and the time.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .layout(.row("Padding", "12pt sides, 8pt top and bottom", token: "SpacingTokens.sm / xs"), .row("Spacing", "6pt between cards"),
                        .row("Corner", "10pt", token: "LayoutTokens.FloatingSurface.rowCornerRadius")),
                .material(.row("Fill", "group fill", token: "ColorTokens.Workspace.groupFill")),
                .type(.row("Title", "13pt; semibold while new, regular after"), .row("Time", "11pt tertiary, relative")),
            ], rounds: [r17], files: [views]),
            SpecElement(number: "3.6", name: "Opened card", summary: "Click a card: it fades open to the whole message.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .behaviour(.row("Shows", "the server, the rest of the message (selectable, monospaced 11pt), small Open Tab or Show Server (when the tab or server still exists) and Copy buttons, and the notification's action (Reconnect, Go to Error) while it still applies"),
                           .row("Indent", "24pt", token: "SpacingTokens.lg")),
                .motion(.row("Opens", "fade, 0.45s")),
            ], rounds: [r17], files: [views]),
            SpecElement(number: "3.7", name: "What is kept", summary: "Every event is recorded, muted or not.", states: [SpecState(key: "history", name: "History open")], defaultState: "history", groups: [
                .behaviour(.row("Kept", "500 events, across launches", token: "NotificationHistory.capacity"),
                           .row("Muted toast", "still recorded")),
            ], files: ["Echo/Sources/Shared/Notifications/"]),
        ]),
        SpecPart(number: "4", name: "Bell", summary: "The toolbar button that opens the history.", elements: [
            SpecElement(number: "4.1", name: "Bell button", summary: "In the toolbar, with an unread badge.", groups: [
                .type(.row("Badge", "the system badge with the unread count", token: ".badge(unreadCount)")),
                .states(.row("History showing", "the filled bell"),
                        .row("A long operation running", "a mini spinner at the bell's bottom right, once it has run 1 s (round 34)", token: "LayoutTokens.Bell.busyDelay")),
                .behaviour(.row("Click", "the history takes the inspector's column and the badge clears; click again to put it away"),
                           .row("Tooltip", "Notifications, with (N unread) when there are unread events, and \"· Backup shop running\" or \"· 2 operations running\""),
                           .row("Which operations", "every ActivityEngine operation except query runs, which show on Run", token: "ActivityEngine.bellOperations")),
            ], rounds: [r15, "ongoing.refresh-and-activity-r34"], files: [bell]),
            SpecElement(number: "4.2", name: "Bell and inspector button", summary: "They switch the column between history and details.", groups: [
                .behaviour(.row("Bell, then the bell again", "the history, then the column closes; it never falls back to the details"),
                           .row("Inspector button", "from the history it switches the column to the details")),
            ], files: [column, bell]),
        ]),
    ]
}
