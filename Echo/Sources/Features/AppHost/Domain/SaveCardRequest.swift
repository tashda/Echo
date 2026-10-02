import Foundation

/// Where saved SQL goes (round IC, H1).
enum SaveDestination: String, Sendable {
    case bookmarks
    case file
}

/// The Save card's job (round IC): save a query tab (its home becomes what you pick), or keep a
/// statement as a bookmark (from History, a selection, or Save to Bookmarks on a tab that already
/// has a home), without touching any tab.
struct SaveCardRequest: Identifiable {
    enum Origin: Equatable {
        /// The tab's home becomes the bookmark or file you pick.
        case tab(UUID)
        /// Only a new bookmark or file; no tab changes.
        case statement
    }

    let id = UUID()
    let origin: Origin
    let sql: String
    let connectionID: UUID
    let databaseName: String?
    /// The card's title and the name it suggests.
    let suggestedName: String
    var destination: SaveDestination
    /// A selection or a history run can't become a file's home, but can still be written out.
    var allowsFile = true
    /// The tab the card hangs from; without one (History) it sits by the inspector.
    var anchorTabID: UUID?
}
