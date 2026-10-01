import SwiftUI

/// A button in a tab's toolbar group.
struct LabTBButton: Hashable {
    let title: String
    let symbol: String
    var runningTitle: String?
    var runningSymbol: String?
    var isOn = false
}

/// A tab as round 37.5 draws it: its symbol and colour, its buttons in groups, and what stays on
/// a tool's header line.
struct LabTBTab: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    /// Run for a query, the main action for a tool.
    var main: LabTBButton?
    var isQuery = false
    var groups: [[LabTBButton]] = []
    var picker: String?
    var search: String?
    var subtitle = "dkloosql10-p"
    var pages: [String] = []

    static let query = LabTBTab(
        id: "q2", title: "Query 2", symbol: "tablecells", tint: ColorTokens.accent,
        main: LabTBButton(title: "Run", symbol: "play.fill", runningTitle: "Cancel", runningSymbol: "stop.fill"), isQuery: true,
        groups: [[.init(title: "Format", symbol: "sparkles"), .init(title: "Validate", symbol: "exclamationmark.triangle"),
                  .init(title: "Context Help", symbol: "text.book.closed"), .init(title: "Execution Plan", symbol: "flowchart")],
                 [.init(title: "SQLCMD Mode", symbol: "terminal"), .init(title: "Statistics", symbol: "chart.bar", isOn: true)]])
    static let profiler = LabTBTab(
        id: "pr", title: "SQL Profiler", symbol: "chart.xyaxis.line", tint: ColorTokens.Status.info,
        main: LabTBButton(title: "Start Trace", symbol: "play.fill", runningTitle: "Stop Trace", runningSymbol: "stop.fill"),
        groups: [[.init(title: "Events", symbol: "list.bullet"), .init(title: "Clear", symbol: "trash"), .init(title: "Export", symbol: "square.and.arrow.up")]],
        picker: "All Databases", search: "Filter events", subtitle: "dkloosql10-p · 1,204 events")
    static let policy = LabTBTab(
        id: "pm", title: "Policy Management", symbol: "checkmark.shield", tint: ColorTokens.Status.success,
        groups: [[.init(title: "Evaluate", symbol: "checkmark.circle"), .init(title: "Refresh", symbol: "arrow.clockwise")]],
        search: "Search policies", subtitle: "dkloosql10-p · 14 policies", pages: ["Policies", "Conditions", "Facets", "History"])
    static let activity = LabTBTab(
        id: "am", title: "Activity Monitor", symbol: "waveform.path.ecg", tint: ColorTokens.Status.warning,
        main: LabTBButton(title: "Pause", symbol: "pause.fill"),
        groups: [[.init(title: "Refresh Now", symbol: "arrow.clockwise")]],
        picker: "Every 5 s", subtitle: "dkloosql10-p · updated 2 s ago", pages: ["Processes", "Waits", "I/O", "Queries"])
    static let structure = LabTBTab(
        id: "st", title: "dbo.orders", symbol: "rectangle.split.3x1", tint: ColorTokens.Status.info,
        main: LabTBButton(title: "Add Column", symbol: "plus"), subtitle: "dkloosql10-p · shop",
        pages: ["Columns", "Indexes", "Constraints", "Relations"])
    static let errorLog = LabTBTab(
        id: "el", title: "Error Log", symbol: "doc.text.magnifyingglass", tint: ColorTokens.Status.error,
        groups: [[.init(title: "Cycle Log", symbol: "arrow.triangle.2.circlepath"), .init(title: "Refresh", symbol: "arrow.clockwise")]],
        picker: "Current", search: "Search log", pages: ["SQL Server", "SQL Agent"])
    static let diagram = LabTBTab(id: "dg", title: "shop diagram", symbol: "point.3.connected.trianglepath.dotted", tint: ColorTokens.Status.info,
                                  groups: [[.init(title: "Export", symbol: "square.and.arrow.up")]], search: "Filter tables")
    static let noButtons = LabTBTab(id: "ag", title: "Availability Groups", symbol: "server.rack", tint: ColorTokens.accent)

    static func == (lhs: LabTBTab, rhs: LabTBTab) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The buttons that move to the toolbar for a tool, by what moves (MV0 to MV2).
    func toolbarGroups(_ move: LabTBMove) -> [[LabTBButton]] {
        if isQuery { return groups }
        switch move {
        case .main: return []
        case .buttons, .everything: return groups
        }
    }
}
