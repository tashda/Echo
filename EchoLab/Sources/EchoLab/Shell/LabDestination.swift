/// What the sidebar can show: the inbox, an area, or a single Test or Reference page.
enum LabDestination: Hashable {
    case inbox
    case area(String)
    case page(String)
}
