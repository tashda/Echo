/// Every page in the lab. Add a page to its area's list (`OngoingPages`, `DecidedPages`,
/// `TestPages`); the sidebar builds itself from this.
@MainActor enum LabRegistry {
    static let pages: [LabPage] = OngoingPages.all + DecidedPages.all + LabAreas.all.map(\.asBuiltPage) + ReferencePages.all + TestPages.all

    static func pages(in section: LabSection) -> [LabPage] {
        pages.filter { $0.section == section }
    }

    static func page(id: String?) -> LabPage? {
        pages.first { $0.id == id }
    }
}
