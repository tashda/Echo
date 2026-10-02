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
        case .section, .sectionAtRight: return section ?? engine
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

/// The title banner header's measures, in one place (rounds 53 and 58): the layout reserves
/// `headerHeight` for the server row and the drawing frames its lines with the same numbers, so
/// the block is tight (no gap, no overlap, nothing clipped) for every name size, line above the
/// name and spacing. The header is the server row, from the card's top edge to the dock; the dock
/// is the row under it, whose capsule is centred in its own slot (a few points of room around it).
///
/// From the top: the space (6pt Tight, 10pt Standard), the line over the name (10pt type in a 12pt
/// line) and a 3pt gap, the name (its size x 1.2, rounded), and under it nothing when Tight or 4pt
/// when Standard. With the section at the right of the name, the line shares the name's row and
/// adds no height of its own. With nothing above the name the header is the name and the space.
nonisolated struct ServerHeaderMetrics: Equatable, Sendable {
    /// The eyebrow's line: 10pt type at 1.2.
    static let eyebrowLineHeight = 12.0
    /// The gap between the eyebrow and the name.
    static let lineGap = 3.0
    /// How much of the name's row the section at the right may take, at most.
    static let rightLabelShare = 0.4
    /// The line height of type: the size times this, rounded.
    static let lineHeightRatio = 1.2

    let nameSize: ServerHeaderNameSize
    let eyebrow: ServerHeaderEyebrowLine
    let spacing: ServerHeaderSpacing

    init(nameSize: ServerHeaderNameSize, eyebrow: ServerHeaderEyebrowLine, spacing: ServerHeaderSpacing = .tight) {
        self.nameSize = nameSize
        self.eyebrow = eyebrow
        self.spacing = spacing
    }

    init(look: ServerHeaderLook) {
        self.init(nameSize: look.nameSize, eyebrow: look.eyebrow, spacing: look.spacing)
    }

    /// True when a line sits over the name.
    var hasEyebrowAbove: Bool { eyebrow.isOverName }
    /// The space above the lines.
    var topInset: Double { spacing.topInset }
    /// Room under the name before the dock.
    var bottomInset: Double { spacing.dockGap }
    var nameLineHeight: Double { (nameSize.points * Self.lineHeightRatio).rounded() }
    /// The name's row: the name, or the taller of the name and the section at its right.
    var nameRowHeight: Double {
        eyebrow == .sectionAtRight ? max(nameLineHeight, Self.eyebrowLineHeight) : nameLineHeight
    }
    /// The line over the name and its gap; nothing without the line.
    var eyebrowBlockHeight: Double { hasEyebrowAbove ? Self.eyebrowLineHeight + Self.lineGap : 0 }
    /// The lines together: the line over the name, then the name's row.
    var linesHeight: Double { eyebrowBlockHeight + nameRowHeight }
    /// The server row's whole height, from the card's top edge to the dock.
    var headerHeight: Double { topInset + linesHeight + bottomInset }

    /// What to add to a row slot of `slot` so the row is exactly `headerHeight`; negative when
    /// the header is tighter than the slot.
    func extraHeight(overSlot slot: Double) -> Double { headerHeight - slot }
}
