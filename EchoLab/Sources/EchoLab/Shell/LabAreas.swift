/// Every area, in sidebar order, and which area each round belongs to.
@MainActor
enum LabAreas {
    static let all: [LabArea] = [
        FoundationsArea.area,
        ExplorerTreeArea.area,
        pending("tabs", "Tabs and tool pages", "rectangle.topthird.inset.filled", "The tab strip, tool pages inside a tab, and the tab overview."),
        pending("window", "Window and cards", "macwindow", "The canvas, the server rail, cards, corners and the toolbar."),
        pending("editor", "Editor and running", "curlybraces", "The editor card, gutter, fonts, statement focus and the Run controls."),
        pending("footer-results", "Footer and results", "tablecells", "The footer, the database switcher and the results card."),
        pending("inspector", "Inspector", "sidebar.right", "The column of cards on the canvas."),
        pending("connections", "Connections", "externaldrive.connected.to.line.below", "Welcome, Quick Connect, New Connection and Manage Connections."),
        pending("echosense", "EchoSense", "text.badge.star", "The completion popup: rows, selection, details and ghost text."),
        pending("notifications", "Notifications", "bell", "Toasts, the bell and the notification history."),
    ]

    private static func pending(_ id: String, _ title: String, _ symbol: String, _ summary: String) -> LabArea {
        LabArea(id: id, title: title, symbol: symbol, summary: summary, asBuilt: .pending(title))
    }

    static func area(id: String?) -> LabArea? { all.first { $0.id == id } }

    /// Round pages (`LabPage.id`) and the area they belong to.
    static let roundAreas: [String: String] = [
        "decided.round9-footer-scroller-tabs": "window",
        "decided.round10-footer-and-switcher": "footer-results",
        "decided.round11-tab-bar": "tabs",
        "decided.round12-two-line-tabs": "tabs",
        "decided.round13-tab-directions": "tabs",
        "decided.tree-card-s4-quiet": "explorer-tree",
        "decided.window-canvas-and-cards": "window",
        "decided.rail-servers": "window",
        "decided.tree-sticky-header": "explorer-tree",
        "decided.results-grid": "footer-results",
        "decided.toasts-and-notifications": "notifications",
        "decided.inspector-column": "inspector",
        "ported.Round 15 · Run": "editor",
        "ported.Round 15 · inspector": "inspector",
        "ported.Round 15 · notifications": "notifications",
        "ported.Round 14 · tab bar and pages": "tabs",
        "ported.Round 14 · section dock": "explorer-tree",
        "ported.Round 14 · connections": "connections",
        "ported.Round 14 · EchoSense selection": "echosense",
    ]

    static func areaID(ofPage id: String) -> String? {
        if id.hasPrefix("asbuilt.") { return String(id.dropFirst("asbuilt.".count)) }
        return roundAreas[id]
    }

    /// Rounds of an area, not including its As built page.
    static func rounds(in area: LabArea) -> [LabPage] {
        LabRegistry.pages.filter { roundAreas[$0.id] == area.id }
    }
}
