/// The areas of Echo Labs, in sidebar order.
enum LabSection: String, CaseIterable, Identifiable {
    case ongoing = "Ongoing work"
    case decided = "Decided"
    case areas = "Areas"
    case reference = "Reference"
    case test = "Test"

    var id: String { rawValue }
}

/// Where a piece of design work is in its life (CLAUDE.md, Echo Labs workflow). The owner moves
/// it with Accept, Confirm, comments and Reopen; the agent moves it to In Echo and freezes it.
enum LabStatus: String, Codable, CaseIterable {
    /// The owner has feedback the agent has not acted on yet. Agents read this first.
    case newFeedback = "New feedback"
    /// A playground the owner is judging.
    case judging = "Judging"
    /// The owner accepted the verdict; the agent builds it into Echo.
    case accepted = "Accepted"
    /// Built into Echo; waiting for the owner to check it in the running app.
    case inEcho = "In Echo"
    /// Confirmed in the running app. The agent freezes it into the library.
    case decided = "Decided"

    var section: LabSection { self == .decided ? .decided : .ongoing }
}
