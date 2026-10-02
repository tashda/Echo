import SwiftUI

/// Round 51's choices. The trail (the rail's pill of servers) shows every connected server as two
/// letters in a colour; with ten servers that is the opposite of "find it in under a second".
/// These vary what one item looks like, how a name is revealed, how much the user can customise,
/// and where a minimised card goes.
enum LabTIStyle: String, CaseIterable {
    case monogram = "TI0 · Monogram in the colour (Echo today)"
    case disc = "TI1 · Monogram on a filled disc"
    case tile = "TI2 · Monogram on a tinted rounded square"
    case ring = "TI3 · Monogram inside a ring of the colour"
    case engine = "TI4 · The engine's symbol, in the colour"
    case glyph = "TI5 · The user's own symbol or emoji on a tinted disc"
    case bar = "TI6 · Monogram with a bookmark bar of the colour"
    case badge = "TI7 · Monogram on a neutral tile with an engine badge"
    case labelled = "TI8 · A disc with the name under it"

    var number: String { rawValue.components(separatedBy: " · ").first ?? rawValue }

    var summary: String {
        switch self {
        case .monogram: "Two letters; grey, or the server's colour with Server Header Colour set to the server's colour. Selected is bold on a white disc."
        case .disc: "A solid disc of the colour with white letters. The strongest colour per item: ten servers are ten distinct dots, readable at a glance."
        case .tile: "A rounded square (the shape of an app icon, not of the disc that marks the selection), tinted, with the letters in the colour."
        case .ring: "A 2pt ring of the colour with the letters in primary text. Lighter than a disc; the colour is a line, so it reads less at the edge of vision."
        case .engine: "The product's symbol (cylinder, and so on) in the colour. Tells SQL Server from PostgreSQL immediately, but two servers of one product look alike apart from colour."
        case .glyph: "A symbol or an emoji the user picked for this server, on a tinted disc: a flame for prod, a flask for test. Falls back to the letters until one is chosen."
        case .bar: "Today's monogram with a 3pt bar in the colour on the pill's leading edge, like a bookmark. Quiet, and the selection disc stays the only filled shape."
        case .badge: "A neutral tile with the letters and a small dot in the corner carrying the colour. Two cues, so a colour-blind user still has the letters."
        case .labelled: "A smaller disc with the first eight characters of the name under it. The rail widens to about 52pt; the name is always visible, nothing to hover."
        }
    }
}

/// How a server's name is revealed.
enum LabTINames: String, CaseIterable {
    case tooltip = "NM0 · A tooltip after a moment (Echo today)"
    case bubble = "NM1 · A glass bubble beside the item, at once"
    case expand = "NM2 · The rail widens to show every name while you hover it"

    var summary: String {
        switch self {
        case .tooltip: "The system tooltip: about a second of hovering, then name and host."
        case .bubble: "Name and product in a glass pill to the right of the item, immediately; it overlaps the tree, like the + menu would."
        case .expand: "Hover anywhere on the rail and it opens to a list (name and product), over the tree, like Arc's or Slack's sidebar; it closes when you leave."
        }
    }
}

/// How much of the item the user can change.
enum LabTICustom: String, CaseIterable {
    case automatic = "CU0 · Nothing: letters from the name, colour from the connection"
    case colour = "CU1 · The colour"
    case glyph = "CU2 · The colour and a symbol or emoji"
    case full = "CU3 · The colour, a symbol or emoji, the letters and the shape"

    var summary: String {
        switch self {
        case .automatic: "Today. Two servers with names like prod-eu-pg01 and prod-eu-pg02 get the same letters."
        case .colour: "A colour from the palette or any colour: already a connection property, now also reachable from the rail."
        case .glyph: "Adds a symbol or an emoji. With TI5 this is the whole look of the item."
        case .full: "Adds two letters of your own and a shape (circle, rounded square, square). Everything is optional; unset parts stay automatic."
        }
    }

    var showsColour: Bool { self != .automatic }
    var showsGlyph: Bool { self == .glyph || self == .full }
    var showsText: Bool { self == .full }
    var showsShape: Bool { self == .full }
}

/// Where a minimised card goes. The trail always means "the servers I am connected to"; a shelf
/// is somewhere to find the cards I tucked away.
enum LabTIShelf: String, CaseIterable {
    case inList = "SH0 · Stay in the list as a header-only card (Echo today)"
    case section = "SH1 · A Minimized section at the foot of the list, as compact rows"
    case stripBottom = "SH2 · A strip of chips under the cards"
    case stripTop = "SH3 · A strip of chips above the cards"
    case tray = "SH4 · A tray in the rail: minimized servers leave the trail and wait in a popover"
    case ring = "SH5 · Stay in the trail as dashed rings; the card leaves the list"

    var summary: String {
        switch self {
        case .inList: "The card folds to its header and stays where it was. The list keeps its length and its order; every server is in two places (list and trail)."
        case .section: "Open cards stay at the top; folded ones move to a short section at the foot, a row each with the colour and the name. One click restores a card in place."
        case .stripBottom: "Folded cards leave the list and become glass chips at its foot, like windows in the Dock. The chip wears the same mark as the trail."
        case .stripTop: "The same chips above the cards, where you look first. The strip pushes the cards down while it has chips."
        case .tray: "The trail shows only servers whose card is open. A tray button at its foot (with a count) opens a list of the minimized ones. The most distinct from the trail, and one more click."
        case .ring: "One place, two states: the server stays in the trail with a dashed ring and a dimmed mark; its card leaves the list. Clicking the ring opens the card."
        }
    }
}

/// A shape for the item's mark.
enum LabTIShape: String, CaseIterable {
    case circle = "Circle", squircle = "Rounded", square = "Square"

    func path(size: CGFloat) -> AnyShape {
        switch self {
        case .circle: AnyShape(Circle())
        case .squircle: AnyShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        case .square: AnyShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
        }
    }
}

enum LabTIGlyph: Hashable {
    case symbol(String)
    case emoji(String)
}

/// What the user set for one server; nil or empty parts stay automatic.
struct LabTICustomisation: Equatable {
    var color: Color?
    var glyph: LabTIGlyph?
    var text = ""
    var shape: LabTIShape?
}

struct LabTILook {
    var style: LabTIStyle
    var names: LabTINames
    var shelf: LabTIShelf
    var custom: LabTICustom

    static let today = LabTILook(style: .monogram, names: .tooltip, shelf: .inList, custom: .automatic)

    @MainActor init(_ values: RoundValues) {
        style = LabTIStyle(rawValue: values["style"]) ?? .disc
        names = LabTINames(rawValue: values["names"]) ?? .bubble
        shelf = LabTIShelf(rawValue: values["shelf"]) ?? .ring
        custom = LabTICustom(rawValue: values["custom"]) ?? .glyph
    }

    init(style: LabTIStyle, names: LabTINames, shelf: LabTIShelf, custom: LabTICustom) {
        self.style = style
        self.names = names
        self.shelf = shelf
        self.custom = custom
    }
}

/// A sample server with what the trail needs.
struct LabTIServer: Identifiable {
    let server: LabSHServer
    let monogram: String
    let engine: String
    var glyph: LabTIGlyph?
    var id: String { server.id }

    static let all: [LabTIServer] = [
        .init(server: .production, monogram: "DP", engine: "cylinder.split.1x2.fill", glyph: .emoji("🔥")),
        .init(server: .test, monogram: "DT", engine: "cylinder.split.1x2.fill", glyph: .emoji("🧪")),
        .init(server: .development, monogram: "18", engine: "externaldrive.fill", glyph: .symbol("hammer.fill")),
        .init(server: LabSHServer(id: "mssql25", name: "mssql25", monogram: "25", product: "SQL Server 2025", login: "sa", latency: "5 ms",
                                  host: "mssql25.local:1433", color: Color.purple, rows: ["AdventureWorks", "master", "tempdb"]),
              monogram: "25", engine: "cylinder.split.1x2.fill", glyph: .symbol("sparkles")),
        .init(server: LabSHServer(id: "norway", name: "norway", monogram: "NO", product: "MySQL 8.4", login: "root", latency: "31 ms",
                                  host: "norway.example.com:3306", color: Color.teal, rows: ["fjord", "mysql", "sys"]),
              monogram: "NO", engine: "leaf.fill", glyph: .symbol("snowflake")),
        .init(server: LabSHServer(id: "tippr", name: "tippr", monogram: "TI", product: "PostgreSQL 16", login: "tippr", latency: "9 ms",
                                  host: "tippr.internal:5432", color: ColorTokens.Status.warning, rows: ["tippr", "postgres"]),
              monogram: "TI", engine: "externaldrive.fill", glyph: .emoji("🎯")),
        .init(server: LabSHServer(id: "pgservices", name: "postgres_services", monogram: "PS", product: "PostgreSQL 17", login: "svc", latency: "4 ms",
                                  host: "pg-services:5432", color: Color.pink, rows: ["services", "postgres"]),
              monogram: "PS", engine: "externaldrive.fill", glyph: .symbol("gearshape.2.fill")),
        .init(server: LabSHServer(id: "readsoft", name: "ReadsoftEast", monogram: "RE", product: "SQL Server 2019", login: "sa", latency: "44 ms",
                                  host: "readsoft-east:1433", color: Color.indigo, rows: ["Readsoft", "master"]),
              monogram: "RE", engine: "cylinder.split.1x2.fill", glyph: .symbol("doc.text.fill")),
        .init(server: LabSHServer(id: "corporate", name: "corporate", monogram: "CO", product: "SQL Server 2022", login: "svc", latency: "18 ms",
                                  host: "corp-sql.local:1433", color: Color.gray, rows: ["Corp", "master"]),
              monogram: "CO", engine: "cylinder.split.1x2.fill", glyph: .symbol("building.2.fill")),
    ]

    static func named(_ id: String) -> LabTIServer { all.first { $0.id == id } ?? all[0] }
}
