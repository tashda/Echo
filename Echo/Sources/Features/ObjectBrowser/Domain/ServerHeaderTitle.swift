import Foundation

/// What the title banner header says over the server's name (round 53, EB0 to EB3). Open, the
/// line can name the dock's current section; closed, the card is not "in" any section, so the
/// section never shows and the engine takes its place (the owner's note on round 53).
nonisolated enum ServerHeaderEyebrow {
    /// The engine in capitals, without a version: SQL SERVER, POSTGRESQL, MYSQL, SQLITE.
    static func engineName(for databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL: "SQL SERVER"
        case .postgresql: "POSTGRESQL"
        case .mysql: "MYSQL"
        case .sqlite: "SQLITE"
        }
    }

    /// The line above the name, or nil for none. `section` is the dock's current section title.
    static func text(line: ServerHeaderEyebrowLine, engine: String, section: String?, isOpen: Bool) -> String? {
        let section = isOpen ? section?.uppercased() : nil
        switch line {
        case .none: return nil
        case .engine: return engine
        case .section: return section ?? engine
        case .engineAndSection: return section.map { "\(engine) · \($0)" } ?? engine
        }
    }
}

/// Type colour on the banner (round 53, TC1): white, or dark on a light colour.
nonisolated enum ServerHeaderContrast {
    /// Above this luminance (Rec. 709 weights on sRGB components) the type turns dark: amber and
    /// yellow banners get dark type, blues and reds keep white.
    static let darkTypeThreshold = 0.62

    static func luminance(red: Double, green: Double, blue: Double) -> Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    static func prefersDarkType(red: Double, green: Double, blue: Double) -> Bool {
        luminance(red: red, green: green, blue: blue) > darkTypeThreshold
    }
}

/// The title banner header's measures, in one place: the layout reserves `headerHeight` for the
/// server row and the drawing frames its lines with the same numbers, so the block is tight (no
/// gap, no overlap, nothing clipped) for every name size, line above the name and typeface.
/// Line heights are the fonts' approximate leading; the drawing fixes each line to its height.
nonisolated struct ServerHeaderMetrics: Equatable, Sendable {
    /// The eyebrow's line: 11pt type.
    static let eyebrowLineHeight = 14.0
    /// The gap between the eyebrow and the name.
    static let lineGap = 2.0
    /// The space above the lines when the card is open.
    static let topInset = 12.0
    /// Room under the name before the dock.
    static let bottomInset = 4.0

    let nameSize: ServerHeaderNameSize
    let hasEyebrow: Bool

    init(nameSize: ServerHeaderNameSize, eyebrow: ServerHeaderEyebrowLine) {
        self.nameSize = nameSize
        self.hasEyebrow = eyebrow != .none
    }

    init(look: ServerHeaderLook) {
        self.init(nameSize: look.nameSize, eyebrow: look.eyebrow)
    }

    var nameLineHeight: Double { (nameSize.points * 1.22).rounded(.up) }
    /// The line over the name and its gap; nothing without the line.
    var eyebrowBlockHeight: Double { hasEyebrow ? Self.eyebrowLineHeight + Self.lineGap : 0 }
    /// The lines together: the line over the name, then the name.
    var linesHeight: Double { eyebrowBlockHeight + nameLineHeight }
    /// The server row's whole height, from the card's top edge to the dock.
    var headerHeight: Double { Self.topInset + linesHeight + Self.bottomInset }

    /// What to add to a row slot of `slot` so the row is exactly `headerHeight`; negative when
    /// the header is tighter than the slot.
    func extraHeight(overSlot slot: Double) -> Double { headerHeight - slot }
}
