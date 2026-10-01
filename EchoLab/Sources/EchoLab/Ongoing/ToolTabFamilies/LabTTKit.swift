import SwiftUI

/// The five families of tool tabs (round 37.1).
enum LabTTFamily: String, CaseIterable {
    case monitor = "Monitor"
    case manage = "Manage"
    case health = "Health"
    case properties = "Properties"
    case canvas = "Canvas"

    var summary: String {
        switch self {
        case .monitor: "Live data that changes while you watch: tiles, a live table, pause and an interval."
        case .manage: "A list of things you create, change and remove, with the selected one's details."
        case .health: "Findings about the server or database, worst first, each with a fix you can run."
        case .properties: "One object's settings as a grouped form, applied together."
        case .canvas: "A drawing you move around in: tables and lines, zoom, a floating bar of tools."
        }
    }

    var tools: [String] {
        switch self {
        case .monitor: ["Activity Monitor", "SQL Profiler", "Extended Events", "Query Store", "psql console"]
        case .manage: ["Agent Jobs", "Server Security", "Database Security", "Policy Management", "Availability Groups", "Resource Governor", "Extensions", "Advanced Objects", "Database Mail"]
        case .health: ["Maintenance (SQL Server)", "Maintenance (PostgreSQL)", "Tuning Advisor", "Error Log"]
        case .properties: ["Server Properties", "Table Structure", "Extension Structure"]
        case .canvas: ["Schema Diagram", "Query Builder", "Schema Diff"]
        }
    }

    var symbol: String {
        switch self {
        case .monitor: "waveform.path.ecg"
        case .manage: "list.bullet.rectangle"
        case .health: "stethoscope"
        case .properties: "slider.horizontal.3"
        case .canvas: "point.3.connected.trianglepath.dotted"
        }
    }
}

/// A tool as its header and toolbar row show it.
struct LabTTTool {
    let name: String
    let symbol: String
    let tint: Color
    let subtitle: String
    var pages: [String] = []
    var primary: (title: String, symbol: String)?
    var secondary: [(symbol: String, help: String)] = []
    var picker: (label: String, value: String)?
    var status: String?
    var searchPrompt: String?

    static let profiler = LabTTTool(name: "SQL Profiler", symbol: "chart.xyaxis.line", tint: ColorTokens.Status.info, subtitle: "dkloosql10-p · 1,204 events",
                                    primary: ("Start Trace", "play.fill"), secondary: [("trash", "Clear"), ("list.bullet", "Events (12)"), ("square.and.arrow.up", "Export")],
                                    picker: ("Database", "All Databases"), status: "Tracing", searchPrompt: "Filter events")
    static let policy = LabTTTool(name: "Policy Management", symbol: "checkmark.shield", tint: ColorTokens.Status.success, subtitle: "dkloosql10-p · 14 policies",
                                  pages: ["Policies", "Conditions", "Facets", "History"], primary: ("New Policy", "plus"),
                                  secondary: [("checkmark.circle", "Evaluate"), ("square.and.arrow.down", "Import")], searchPrompt: "Search policies")
    static let activity = LabTTTool(name: "Activity Monitor", symbol: "waveform.path.ecg", tint: ColorTokens.Status.warning, subtitle: "dkloosql10-p · updated 2 s ago",
                                    pages: ["Processes", "Waits", "I/O", "Queries"], primary: ("Pause", "pause.fill"),
                                    secondary: [("arrow.clockwise", "Refresh")], picker: ("Every", "5 seconds"), searchPrompt: "Filter sessions")
}

/// Round 37.2: the header and toolbar row.
enum LabTTHeaderStyle: String, CaseIterable {
    case today = "UH0 · Header, then a toolbar row with mixed buttons (today)"
    case oneRow = "UH1 · One row: name at the left, every control at the right"
    case twoRows = "UH2 · Two rows: name and primary action, then pages, filters and search"
    case glassBar = "UH3 · Name on the canvas, every control in one glass capsule"
    case windowToolbar = "UH4 · The controls in the window's toolbar while the tab is in front"

    var summary: String {
        switch self {
        case .today: "TT2's header, then TabSectionToolbar: a bordered tinted primary, borderless icons, a menu picker with its own label, a green word for status."
        case .oneRow: "Saves the toolbar row's 40pt; gets crowded with pages and a picker."
        case .twoRows: "The name line carries what the tool is and its one main action; the second line is how you look at it."
        case .glassBar: "Like the editor's find capsule (28.12, FB5): one floating piece holds the controls, in the editor's design language."
        case .windowToolbar: "Mail and Finder put view controls in the toolbar; Echo's toolbar already has three capsules."
        }
    }
}

/// Round 37.3: the controls.
enum LabTTPrimary: String, CaseIterable {
    case today = "PA0 · Bordered, small, tinted (today)"
    case glass = "PA1 · Glass capsule: symbol in colour, word in grey"
    case prominent = "PA2 · Prominent capsule in the accent colour"
    case text = "PA3 · Symbol and word in the accent colour, no shape"
}

enum LabTTSecondary: String, CaseIterable {
    case today = "SA0 · Bare symbols, no shape (today)"
    case circles = "SA1 · Each in a glass circle"
    case group = "SA2 · Together in one glass capsule"
}

enum LabTTPicker: String, CaseIterable {
    case today = "PK0 · A label, then a pop-up button (today)"
    case pill = "PK1 · One glass pill: symbol, value and a chevron"
    case chip = "PK2 · A filter chip that is grey until you change it"
}

enum LabTTStatus: String, CaseIterable {
    case today = "ST0 · A green word with a symbol (today)"
    case inButton = "ST1 · The primary button turns into Stop with a pulsing dot"
    case pill = "ST2 · A status pill like the footer's"
}

enum LabTTSearch: String, CaseIterable {
    case none = "SF0 · Each tool its own (today: most have none)"
    case capsule = "SF1 · A glass search capsule at the right of the row"
    case expanding = "SF2 · A magnifying glass that opens into a field"
}

struct LabTTLook {
    var header: LabTTHeaderStyle = .twoRows
    var primary: LabTTPrimary = .glass
    var secondary: LabTTSecondary = .group
    var picker: LabTTPicker = .pill
    var status: LabTTStatus = .inButton
    var search: LabTTSearch = .capsule

    static let today = LabTTLook(header: .today, primary: .today, secondary: .today, picker: .today, status: .today, search: .none)

    @MainActor static func from(_ v: RoundValues) -> LabTTLook {
        LabTTLook(header: .init(rawValue: v["header"]) ?? .twoRows, primary: .init(rawValue: v["primary"]) ?? .glass,
                  secondary: .init(rawValue: v["secondary"]) ?? .group, picker: .init(rawValue: v["picker"]) ?? .pill,
                  status: .init(rawValue: v["status"]) ?? .inButton, search: .init(rawValue: v["search"]) ?? .capsule)
    }
}
