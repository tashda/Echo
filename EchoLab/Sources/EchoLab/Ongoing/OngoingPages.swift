/// Work in progress. A page is a playground the owner is judging (`.judging`), or a verdict
/// that is built into Echo and waiting for feedback (`.inEcho`). When the owner confirms it on
/// the real app, the page is frozen into `Decided/` and removed from this list.
@MainActor enum OngoingPages {
    static let all: [LabPage] = PortedPages.ongoing
}
