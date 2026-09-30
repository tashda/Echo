/// The decision library, one `LabDecision` per folder under `Decided/Library/`. A decision lands
/// here when the owner has confirmed it on the real app; see CLAUDE.md, Echo Lab workflow.
@MainActor
enum DecidedPages {
    static let library: [LabDecision] = [
        .round9,
        .round10,
        .round11,
        .round12,
        .round13,
        .treeCard,
        .window,
        .rail,
        .tree,
        .results,
        .floating,
        .inspector
    ]

    static let all: [LabPage] = library.map(\.page)
}
