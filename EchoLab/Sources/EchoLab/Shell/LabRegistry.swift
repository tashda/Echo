/// Every page in the lab. Add a page to its area's list (`OngoingPages`, `DecidedPages`,
/// `TestPages`); the sidebar builds itself from this.
@MainActor enum LabRegistry {
    private static let builtIn: [LabPage] = OngoingPages.all + DecidedPages.all + LabAreas.all.map(\.asBuiltPage) + ReferencePages.all + TestPages.all

    /// Built-in pages plus the fast rounds read from `State/fast-rounds/` (they change while the lab runs).
    static var pages: [LabPage] { builtIn + FastRoundStore.shared.pages }

    static func pages(in section: LabSection) -> [LabPage] {
        pages.filter { $0.section == section }
    }

    static func page(id: String?) -> LabPage? {
        pages.first { $0.id == id }
    }
}
