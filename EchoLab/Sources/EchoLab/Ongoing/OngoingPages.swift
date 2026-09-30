/// Work in progress. A page is a playground the owner is judging (`.judging`), or a verdict
/// that is built into Echo and waiting for feedback (`.inEcho`). When the owner confirms it on
/// the real app, the page is frozen into `Decided/` and removed from this list.
@MainActor enum OngoingPages {
    static let all: [LabPage] = [serverCard, notificationHistory] + PortedPages.ongoing

    /// Round 16: the owner's bugs and feedback on the section dock (TC1) as built in Echo.
    static let serverCard = LabPage.round(
        id: "ongoing.server-card-r16", group: "Explorer tree", title: "Server card · round 16", symbol: "rectangle.stack",
        status: .judging,
        summary: "Header and dock styles, the edge under the pinned header, switching, loading, counts, selection, dock customising and PostgreSQL's sections, beside Echo today.",
        spec: LabServerCardRound.spec)

    /// Round 17: how the notification history looks in the inspector's column and opens.
    static let notificationHistory = LabPage.round(
        id: "ongoing.notification-history-r17", group: "Notifications", title: "Notification history · round 17", symbol: "bell",
        status: .judging,
        summary: "Echo today beside a timeline, cards, and a list with the message below it, each opening a notification to its whole, selectable message.",
        spec: LabNHRound.spec)
}
