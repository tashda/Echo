/// The three areas of Echo Lab, in sidebar order.
enum LabSection: String, CaseIterable, Identifiable {
    case design = "Design"
    case decisions = "Decisions"
    case test = "Test"

    var id: String { rawValue }
}
