import SwiftUI

/// Round 30.1's headers. Rev 2 keeps the five the owner liked (HD0, HD4, HD5, HD7, HD8; HD1, HD2,
/// HD3 and HD6 are gone at their request) and adds variations on each family. Numbers are never reused.
enum LabSHStyle: String, CaseIterable {
    case today = "HD0 · Name and product line (today)"
    case wash = "HD4 · A wash of colour behind the header"
    case cap = "HD9 · A tinted cap down to the dock"
    case glow = "HD10 · A glow from the leading corner"
    case edge = "HD5 · A line of colour along the top"
    case fadingLine = "HD11 · A short line that fades at both ends"
    case bar = "HD12 · A bar of colour beside the name"
    case plate = "HD7 · The name on a tinted glass plate"
    case onePlate = "HD13 · Name and product on one glass plate"
    case pill = "HD14 · The name in a soft pill of colour"
    case banner = "HD8 · A coloured banner"
    case insetBanner = "HD15 · An inset banner, concentric with the card"
    case fadingBanner = "HD16 · A banner that fades into the card"

    var family: LabSHFamily {
        switch self {
        case .today: .plain
        case .wash, .cap, .glow: .wash
        case .edge, .fadingLine, .bar: .line
        case .plate, .onePlate, .pill: .plate
        case .banner, .insetBanner, .fadingBanner: .banner
        }
    }

    /// White text on a filled header.
    var isOnFill: Bool { family == .banner }

    /// "HD4" from "HD4 · A wash…".
    var number: String { rawValue.components(separatedBy: " · ").first ?? rawValue }
    var name: String { rawValue.components(separatedBy: " · ").last ?? rawValue }

    var summary: String {
        switch self {
        case .today: "Bold 13pt name, grey product line, nothing else."
        case .wash: "The colour fades from the card's top edge to clear behind the name and dock."
        case .cap: "A flat, soft tint behind the name and the dock, ending in a hairline of the colour above the rows."
        case .glow: "A soft radial glow from the top leading corner, strongest behind the name; the dock and rows stay plain."
        case .edge: "Redrawn: a 2.5pt line that follows the card's top edge and corners and fades down the sides, instead of a flat band cut off by the corners."
        case .fadingLine: "A 2.5pt line inset from the corners, clear at both ends and full colour in the middle, with a faint glow."
        case .bar: "A 3pt rounded bar of colour beside the name and product line, like a bookmark; the header is otherwise today's."
        case .plate: "The name sits in a capsule of glass tinted with the colour."
        case .onePlate: "Both lines share one tinted glass plate, its corners concentric with the card's."
        case .pill: "The name in the colour on a soft pill of the same colour; no glass."
        case .banner: "The whole header is filled with the colour, white text on top."
        case .insetBanner: "The banner as a panel 5pt in from the card's edges, corners concentric with the card's (as the editor's lane)."
        case .fadingBanner: "Full colour behind the name, fading to clear through the dock, so the card has no hard edge between header and rows."
        }
    }
}

/// The four ideas the owner kept, plus today's plain header.
enum LabSHFamily: String, CaseIterable {
    case plain = "Plain", wash = "Wash", line = "Line", plate = "Plate", banner = "Banner"
    var styles: [LabSHStyle] { LabSHStyle.allCases.filter { $0.family == self } }
}

/// Where the header's colour comes from. Rev 2: this is a setting (Settings › Appearance › Server
/// Header Colour); CS3 is gone because SC1 already sets the server's own colour from the header.
enum LabSHColourSource: String, CaseIterable {
    case none = "CS0 · No colour"
    case server = "CS1 · The server's colour"
    case accent = "CS2 · The accent colour"

    var settingName: String {
        switch self {
        case .none: "None"
        case .server: "Server's Colour"
        case .accent: "Accent Colour"
        }
    }

    var summary: String {
        switch self {
        case .none: "Grey: the header gains presence from shape only."
        case .server: "The colour set on the connection (Manage Connections, or the header's menu with SC1)."
        case .accent: "The system accent colour on every server."
        }
    }
}

enum LabSHSecondLine: String, CaseIterable {
    case productSection = "SL0 · Product · section (today)"
    case product = "SL1 · Product only"
    case login = "SL2 · Login and status"
    case host = "SL3 · Host and port"

    func text(_ server: LabSHServer, section: String) -> String {
        switch self {
        case .productSection: "\(server.product) · \(section)"
        case .product: server.product
        case .login: "\(server.login) · connected · \(server.latency)"
        case .host: server.host
        }
    }
}

/// Which colour the dock's current icon takes. Rev 2: a setting beside Section Dock Icons.
enum LabSHDockTint: String, CaseIterable {
    case accent = "DK0 · Accent, as today"
    case header = "DK1 · The header's colour"

    var settingName: String {
        switch self {
        case .accent: "Accent Colour"
        case .header: "Header's Colour"
        }
    }
}

/// Which sample server the Proposal shows.
enum LabSHSample: String, CaseIterable {
    case production = "Production (red)", test = "Test (green)", development = "Development (blue)"
    var server: LabSHServer {
        switch self {
        case .production: .production
        case .test: .test
        case .development: .development
        }
    }
}

/// A sample server for the cards.
struct LabSHServer: Identifiable {
    let id: String
    let name: String
    let monogram: String
    let product: String
    let login: String
    let latency: String
    let host: String
    let color: Color
    let rows: [String]

    static let production = LabSHServer(
        id: "prod", name: "dkloosql10-p", monogram: "DP", product: "SQL Server 2017", login: "sa", latency: "12 ms",
        host: "dkloosql10-p.global.local:1433", color: ColorTokens.Status.error,
        rows: ["AML", "ccsLDK10", "ccsLDK17", "ccsLDK20", "DBA", "ESB_INTEGRATION", "master"])
    static let test = LabSHServer(
        id: "test", name: "dkloosql20-t", monogram: "DT", product: "SQL Server 2022", login: "GLOBAL\\kenneth", latency: "8 ms",
        host: "dkloosql20-t.global.local:1433", color: ColorTokens.Status.success,
        rows: ["AML_test", "ccsLDK10", "DBA", "master"])
    static let development = LabSHServer(
        id: "dev", name: "postgres18", monogram: "18", product: "PostgreSQL 18", login: "postgres", latency: "1 ms",
        host: "localhost:5432", color: ColorTokens.Status.info,
        rows: ["analytics", "postgres", "shop"])
}

/// Everything a header needs to draw itself.
struct LabSHLook {
    var style: LabSHStyle
    var source: LabSHColourSource
    var secondLine: LabSHSecondLine
    var dockTint: LabSHDockTint

    static let today = LabSHLook(style: .today, source: .none, secondLine: .productSection, dockTint: .accent)

    init(style: LabSHStyle, source: LabSHColourSource, secondLine: LabSHSecondLine, dockTint: LabSHDockTint) {
        self.style = style
        self.source = source
        self.secondLine = secondLine
        self.dockTint = dockTint
    }

    @MainActor init(_ values: RoundValues) {
        style = LabSHStyle(rawValue: values["style"]) ?? .glow
        source = LabSHColourSource(rawValue: values["source"]) ?? .server
        secondLine = LabSHSecondLine(rawValue: values["secondLine"]) ?? .productSection
        dockTint = LabSHDockTint(rawValue: values["dockTint"]) ?? .header
    }

    func color(for server: LabSHServer) -> Color {
        switch source {
        case .none: ColorTokens.Text.secondary
        case .server: server.color
        case .accent: ColorTokens.accent
        }
    }

    var isColoured: Bool { source != .none }

    /// The dock's current icon: the header's colour with DK1 when there is one, else the accent.
    func dockColor(for server: LabSHServer) -> Color {
        dockTint == .header && isColoured ? color(for: server) : ColorTokens.accent
    }

    func with(_ style: LabSHStyle) -> LabSHLook {
        var copy = self
        copy.style = style
        return copy
    }
}
