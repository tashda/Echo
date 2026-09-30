/// What the sidebar can show: the inbox, an area, or a single Test or Reference page.
enum LabDestination: Hashable, Codable {
    case inbox
    case rounds
    case spec
    case area(String)
    case page(String)
}
