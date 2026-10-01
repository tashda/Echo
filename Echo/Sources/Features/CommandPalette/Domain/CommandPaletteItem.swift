import Foundation

/// One row in the ⌘K palette or the toolbar search results (plan K4).
struct CommandPaletteItem: Identifiable {
    enum Section: Int, CaseIterable, Comparable {
        case actions, tabs, objects, history, snippets

        var title: String {
            switch self {
            case .actions: "Actions"
            case .tabs: "Open Tabs"
            case .objects: "Objects"
            case .history: "History"
            case .snippets: "Snippets"
            }
        }

        static func < (lhs: Section, rhs: Section) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let section: Section
    let title: String
    let subtitle: String?
    let systemImage: String
    /// Extra words that match but aren't shown, such as the server of a "New Query" action.
    var keywords: String = ""
    /// Rows that change what the palette shows (Tab Overview) instead of leaving it.
    var keepsPaletteOpen = false
    let perform: @MainActor () -> Void
}
