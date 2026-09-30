/// Work in progress. A page is a playground the owner is judging (`.judging`), or a verdict
/// that is built into Echo and waiting for feedback (`.inEcho`). When the owner confirms it on
/// the real app, the page is frozen into `Decided/` and removed from this list.
@MainActor enum OngoingPages {
    // `Scripts/new-round.py` adds new rounds at the two ROUNDS markers; do not remove them.
    static let all: [LabPage] = [serverCard, notificationHistory , notificationToast , sectionDockSwitching , sectionDockCapsule , sectionDockSections /* ROUNDS-LIST */] + PortedPages.ongoing

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

    /// Round 18: Notification toast.
    static let notificationToast = LabPage.round(
        id: "ongoing.notification-toast-r18", group: "Notifications", title: "Notification toast · round 18", symbol: "bell.badge",
        status: .judging,
        summary: "The toast as Echo draws it today beside a proposal built from the controls. Touches NTF-1.1 to 1.6, NTF-2.1 to 2.2 and NTF-3.1 to 3.6.",
        spec: NotificationToastRound.spec)

    /// Round 19: Section dock: switching.
    static let sectionDockSwitching = LabPage.round(
        id: "ongoing.section-dock-switching-r19", group: "Explorer tree", title: "Section dock: switching · round 19", symbol: "rectangle.stack",
        status: .judging,
        summary: "How a server card changes when you switch sections, and why the card above moves; changes TREE-3.7, TREE-1.2.",
        spec: SectionDockSwitchingRound.spec)

    /// Round 19: Section dock: capsule.
    static let sectionDockCapsule = LabPage.round(
        id: "ongoing.section-dock-capsule-r19", group: "Explorer tree", title: "Section dock: capsule · round 19", symbol: "capsule",
        status: .judging,
        summary: "How the section capsule looks: ten styles, icon weight and size, the current section, hover, and where the section's name shows; changes TREE-3.1 to TREE-3.3.",
        spec: SectionDockCapsuleRound.spec)

    /// Round 19: Section dock: sections.
    static let sectionDockSections = LabPage.round(
        id: "ongoing.section-dock-sections-r19", group: "Explorer tree", title: "Section dock: sections · round 19", symbol: "square.grid.2x2",
        status: .judging,
        summary: "How many sections a dock holds, how SQL Server's eight are grouped, and what happens to sections that don't fit; changes TREE-3.4, TREE-3.5.",
        spec: SectionDockSectionsRound.spec)

    // ROUNDS-DEFINITIONS
}
