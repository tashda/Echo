/// Every page in the lab. Add a page to its area's list (`DesignPages`, `DecisionPages`,
/// `TestPages`); the sidebar builds itself from this.
enum LabRegistry {
    static let pages: [LabPage] = DesignPages.all + DecisionPages.all + TestPages.all

    static func pages(in section: LabSection) -> [LabPage] {
        pages.filter { $0.section == section }
    }

    static func page(id: String?) -> LabPage? {
        pages.first { $0.id == id }
    }
}
