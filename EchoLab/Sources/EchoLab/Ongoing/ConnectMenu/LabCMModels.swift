import SwiftUI

/// Round 52's choices. The + at the foot of the trail opens a system menu below it. The menu lists
/// open sessions and saved connections by folder, then Manage Connections and Quick Connect: it is
/// the system's own menu under a liquid-glass pill. These vary where the list opens (PR), how the
/// + changes while it is open (MP), how the connections are listed (CT), where the actions live
/// (FT), and how many connections there are (CN).
enum LabCMPresentation: String, CaseIterable {
    case menu = "PR0 · A system menu below the + (Echo today)"
    case panel = "PR1 · A glass panel to the right of the +, level with it"
    case drawer = "PR2 · A drawer beside the trail, the height of the window"
    case palette = "PR3 · A palette in the middle of the window, like Spotlight"
    case rail = "PR4 · The trail itself opens: the pill widens into the list"

    var summary: String {
        switch self {
        case .menu: "The system's menu, as in Settings or Finder: familiar, but it can't be searched, can't show a status or a subtitle, and opens under a floating glass pill."
        case .panel: "A glass panel whose top edge is level with the +, to its right, over the tree. It stays beside the thing you pressed; short lists don't fill the window."
        case .drawer: "A full-height panel next to the trail, over the tree, with room for forty connections and a search field that is always visible."
        case .palette: "A command palette in the middle of the window: the same list, with a scrim behind it. Best for typing a name; furthest from the +."
        case .rail: "The pill widens to about 280pt and the list appears below the servers, so trail and connections are one object. The tree is not covered until the list is."
        }
    }
}

/// What the + does while the list is open.
enum LabCMMorph: String, CaseIterable {
    case none = "MP0 · Nothing: it stays a +"
    case turn = "MP1 · The + turns a quarter into an ×"
    case chevronBack = "MP2 · The + becomes a chevron pointing back at the trail"
    case chevronOut = "MP3 · The + becomes a chevron pointing at the list"
    case lift = "MP4 · The + lifts out as its own glass circle and the panel grows from it"

    var summary: String {
        switch self {
        case .none: "Nothing changes: the open list is the only signal."
        case .turn: "The + rotates 45° and is an ×: the oldest convention for \"press again to close\"."
        case .chevronBack: "A symbol replace to ‹ (the + dissolves into a chevron); pressing it closes the list. Reads as \"back\"."
        case .chevronOut: "Replaced by › while open: the arrow points to what opened. Closes on press; reads as \"more over there\"."
        case .lift: "The + gets its own glass circle that detaches from the trail, then the circle and the panel are one liquid shape (glass effect ID) that grows to the right and shrinks back on close."
        }
    }
}

enum LabCMContent: String, CaseIterable {
    case menu = "CT0 · The menu's own list: open, folders as submenus (Echo today)"
    case search = "CT1 · Search first; open connections, then folders as headings"
    case recent = "CT2 · Open, recent, then folders that fold"
    case tiles = "CT3 · Tiles: a mark, a name and the database, two to a row"
    case engine = "CT4 · Grouped by engine, with the folder as a subtitle"

    var summary: String {
        switch self {
        case .menu: "Two sections, folders as submenus with a chevron, hidden until you hover them."
        case .search: "A search field first, then rows with a mark, a name and host · database. Open connections show a dot; the folder is a small heading."
        case .recent: "Open connections, the last three used, then every folder folded: for a long list you usually want one of five."
        case .tiles: "A grid of tiles, like choosing a workspace in Arc or an account in a browser; faster to scan by colour, slower to scan by name."
        case .engine: "SQL Server, PostgreSQL and MySQL as headings: how a DBA often thinks of their servers. The folder (corporate) moves to the row."
        }
    }
}

/// Where Manage Connections, Quick Connect and New Connection live.
enum LabCMFooter: String, CaseIterable {
    case rows = "FT0 · Rows under a divider (Echo today)"
    case bar = "FT1 · A footer bar of three labelled buttons"
    case split = "FT2 · New next to the search field, the other two as a quiet line"

    var summary: String {
        switch self {
        case .rows: "As today, plus New Connection."
        case .bar: "A bar with Manage, Quick Connect and New: always visible below a scrolling list."
        case .split: "The primary action beside the search, the rest as small links at the foot."
        }
    }
}

/// How many saved connections there are.
enum LabCMCount: String, CaseIterable {
    case few = "Five"
    case some = "Twelve (yours)"
    case many = "Forty"

    var limit: Int {
        switch self {
        case .few: 5
        case .some: 12
        case .many: 40
        }
    }
}

struct LabCMLook {
    var presentation: LabCMPresentation
    var morph: LabCMMorph
    var content: LabCMContent
    var footer: LabCMFooter
    var count: LabCMCount

    static let today = LabCMLook(presentation: .menu, morph: .none, content: .menu, footer: .rows, count: .some)

    @MainActor init(_ values: RoundValues) {
        presentation = LabCMPresentation(rawValue: values["presentation"]) ?? .panel
        morph = LabCMMorph(rawValue: values["morph"]) ?? .chevronBack
        content = LabCMContent(rawValue: values["content"]) ?? .search
        footer = LabCMFooter(rawValue: values["footer"]) ?? .bar
        count = LabCMCount(rawValue: values["count"]) ?? .some
    }

    init(presentation: LabCMPresentation, morph: LabCMMorph, content: LabCMContent, footer: LabCMFooter, count: LabCMCount) {
        self.presentation = presentation
        self.morph = morph
        self.content = content
        self.footer = footer
        self.count = count
    }
}

enum LabCMEngine: String, CaseIterable {
    case sqlServer = "SQL Server", postgres = "PostgreSQL", mysql = "MySQL"
}

/// A saved connection or an open session.
struct LabCMConnection: Identifiable {
    let name: String
    let detail: String
    let engine: LabCMEngine
    let color: Color
    var folder: String?
    var isOpen = false
    var isRecent = false
    var id: String { name + (folder ?? "") }

    /// Two letters, as the rail derives them.
    var monogram: String {
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard let first = words.first else { return "?" }
        if words.count >= 2 { return (String(first.prefix(1)) + String(words[1].prefix(1))).uppercased() }
        let digits = first.reversed().prefix(while: \.isNumber)
        if digits.count >= 2 { return String(String(digits.reversed()).suffix(2)) }
        return String(first.prefix(2)).uppercased()
    }

    /// The twelve connections in the owner's screenshot, two of them open, then synthetic ones.
    static func samples(_ count: Int) -> [LabCMConnection] {
        let real: [LabCMConnection] = [
            .init(name: "Test Postgres", detail: "localhost · postgres", engine: .postgres, color: ColorTokens.Status.info, isOpen: true),
            .init(name: "Test MSSQL", detail: "localhost · AdventureWorks2022", engine: .sqlServer, color: ColorTokens.Status.success, isOpen: true),
            .init(name: "dkloosql10-p", detail: "dkloosql10-p.global.local · master", engine: .sqlServer, color: ColorTokens.Status.error, folder: "corporate", isRecent: true),
            .init(name: "dkloosql20-t", detail: "dkloosql20-t.global.local · master", engine: .sqlServer, color: ColorTokens.Status.warning, folder: "corporate"),
            .init(name: "dkhj-axpresql01", detail: "dkhj-axpresql01 · postgres", engine: .postgres, color: Color.indigo, isRecent: true),
            .init(name: "Microsoft SQL Server", detail: "localhost · master", engine: .sqlServer, color: Color.gray),
            .init(name: "mssql25", detail: "mssql25.local · master", engine: .sqlServer, color: Color.purple, isRecent: true),
            .init(name: "mssql25 (Copy)", detail: "mssql25.local · master", engine: .sqlServer, color: Color.purple),
            .init(name: "mysql", detail: "127.0.0.1 · mysql", engine: .mysql, color: Color.teal),
            .init(name: "norway", detail: "norway.example.com · fjord", engine: .mysql, color: Color.mint),
            .init(name: "postgres_services", detail: "pg-services · services", engine: .postgres, color: Color.pink),
            .init(name: "postgres16", detail: "localhost:5416 · postgres", engine: .postgres, color: Color.orange),
            .init(name: "postgres18", detail: "localhost:5418 · postgres", engine: .postgres, color: Color.blue),
            .init(name: "ReadsoftEast", detail: "readsoft-east · Readsoft", engine: .sqlServer, color: Color.brown, folder: "corporate"),
            .init(name: "tippr", detail: "tippr.internal · tippr", engine: .postgres, color: Color.cyan),
        ]
        guard count > real.count - 2 else { return Array(real.prefix(count + 2)) }
        var all = real
        let colours: [Color] = [.red, .orange, .green, .teal, .blue, .purple, .pink, .indigo]
        for index in 0..<(count + 2 - real.count) {
            let engine = LabCMEngine.allCases[index % 3]
            all.append(.init(name: "prod-eu-\(engine == .postgres ? "pg" : engine == .mysql ? "my" : "sql")\(String(format: "%02d", index + 1))",
                             detail: "10.0.\(index / 8).\(10 + index) · app", engine: engine, color: colours[index % colours.count],
                             folder: index % 4 == 0 ? "corporate" : nil))
        }
        return all
    }
}
