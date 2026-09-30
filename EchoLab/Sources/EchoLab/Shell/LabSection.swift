/// The areas of Echo Lab, in sidebar order.
enum LabSection: String, CaseIterable, Identifiable {
    case ongoing = "Ongoing work"
    case decided = "Decided"
    case reference = "Reference"
    case test = "Test"

    var id: String { rawValue }
}

/// Where a piece of design work is in its life. Only Ongoing pages have a status that moves;
/// a page becomes Decided by being frozen into the library (see CLAUDE.md, Echo Lab workflow).
enum LabStatus: String {
    /// A playground the owner is judging.
    case judging = "Judging"
    /// The verdict is built into Echo; waiting for the owner's feedback on the real app.
    case inEcho = "In Echo"
    case decided = "Decided"
}
