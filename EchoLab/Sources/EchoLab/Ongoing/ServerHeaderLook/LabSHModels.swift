import SwiftUI

/// Round 30.1's choices: how the top of a server card looks, and where its colour comes from.
enum LabSHStyle: String, CaseIterable {
    case today = "HD0 · Name and product line (today)"
    case larger = "HD1 · A larger name"
    case monogram = "HD2 · The rail's monogram beside the name"
    case engine = "HD3 · The engine's icon on a coloured tile"
    case wash = "HD4 · A wash of colour behind the header"
    case edge = "HD5 · A line of colour along the top"
    case status = "HD6 · Name with its connection status"
    case plate = "HD7 · The name on a tinted glass plate"
    case banner = "HD8 · A coloured banner"

    var summary: String {
        switch self {
        case .today: "Bold 13pt name, grey product line, nothing else."
        case .larger: "The name at 17pt semibold; the product line stays."
        case .monogram: "The same monogram as the rail, on a soft tile in the colour: the card and the rail read as one server."
        case .engine: "A rounded tile in the colour with the database engine's symbol, like an app icon."
        case .wash: "The colour fades from the card's top edge to clear behind the name and dock."
        case .edge: "A 3pt band of colour along the card's top edge; the header itself stays as today."
        case .status: "A status dot after the name and the login and response time on the second line."
        case .plate: "The name sits in a capsule of glass tinted with the colour."
        case .banner: "The whole header is filled with the colour, white text on top."
        }
    }
}

enum LabSHColourSource: String, CaseIterable {
    case none = "CS0 · No colour"
    case server = "CS1 · The server's colour"
    case accent = "CS2 · The accent colour"
    case custom = "CS3 · A colour you choose per server"

    var summary: String {
        switch self {
        case .none: "Grey: the header gains presence from shape and size only."
        case .server: "The colour set on the connection (Manage Connections), the one the rail's monogram turns when selected."
        case .accent: "The system accent colour on every server."
        case .custom: "A colour picked from the header's menu, remembered for the server; the swatches below stand in for it."
        }
    }
}

/// The swatches standing in for a colour picked in CS3.
enum LabSHCustomColour: String, CaseIterable {
    case purple = "Purple", pink = "Pink", orange = "Orange", teal = "Teal", graphite = "Graphite"

    var color: Color {
        switch self {
        case .purple: Color(nsColor: .systemPurple)
        case .pink: Color(nsColor: .systemPink)
        case .orange: ColorTokens.Status.warning
        case .teal: Color(nsColor: .systemTeal)
        case .graphite: ColorTokens.Text.secondary
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

/// Which colour the dock's current icon takes.
enum LabSHDockTint: String, CaseIterable {
    case accent = "DK0 · Accent, as today"
    case header = "DK1 · The header's colour"
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
    var custom: LabSHCustomColour
    var secondLine: LabSHSecondLine
    var dockTint: LabSHDockTint

    static let today = LabSHLook(style: .today, source: .none, custom: .purple, secondLine: .productSection, dockTint: .accent)

    init(style: LabSHStyle, source: LabSHColourSource, custom: LabSHCustomColour, secondLine: LabSHSecondLine, dockTint: LabSHDockTint) {
        self.style = style
        self.source = source
        self.custom = custom
        self.secondLine = secondLine
        self.dockTint = dockTint
    }

    @MainActor init(_ values: RoundValues) {
        style = LabSHStyle(rawValue: values["style"]) ?? .monogram
        source = LabSHColourSource(rawValue: values["source"]) ?? .server
        custom = LabSHCustomColour(rawValue: values["custom"]) ?? .purple
        secondLine = LabSHSecondLine(rawValue: values["secondLine"]) ?? .productSection
        dockTint = LabSHDockTint(rawValue: values["dockTint"]) ?? .accent
    }

    func color(for server: LabSHServer) -> Color {
        switch source {
        case .none: ColorTokens.Text.secondary
        case .server: server.color
        case .accent: ColorTokens.accent
        case .custom: custom.color
        }
    }

    var isColoured: Bool { source != .none }

    func with(_ style: LabSHStyle) -> LabSHLook {
        var copy = self
        copy.style = style
        return copy
    }
}
