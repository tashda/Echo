/// Work in progress. A page is a playground the owner is judging (`.judging`), or a verdict
/// that is built into Echo and waiting for feedback (`.inEcho`). When the owner confirms it on
/// the real app, the page is frozen into `Decided/` and removed from this list.
@MainActor enum OngoingPages {
    static let all: [LabPage] = [serverCard] + PortedPages.ongoing

    /// Round 16: the owner's bugs and feedback on the section dock (TC1) as built in Echo.
    static let serverCard = LabPage(
        id: "ongoing.server-card-r16",
        section: .ongoing,
        group: "Explorer tree",
        title: "Server card · round 16",
        symbol: "rectangle.stack",
        status: .judging,
        summary: "Header and dock styles, the edge under the pinned header, switching, loading, counts, selection, dock customising and PostgreSQL's sections, beside Echo today."
    ) { LabServerCardPlayground() }
}
