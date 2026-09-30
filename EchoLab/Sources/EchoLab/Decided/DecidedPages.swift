/// The decision library, one `LabDecision` per file under `Decided/Library/`. A decision lands
/// here when the owner has confirmed it on the real app; see CLAUDE.md, Echo Lab workflow.
@MainActor enum DecidedPages {
    static let library: [LabDecision] = []

    static let all: [LabPage] = library.map(\.page) + PortedPages.decided
}
