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

/// How much taller the header slot is than the original one, so the larger name and the line over
/// it fit (round 53). Line heights are the fonts' approximate leading.
nonisolated enum ServerHeaderSlot {
    /// The eyebrow's line: 11pt type.
    static let eyebrowLineHeight = 14.0
    /// The gap between the eyebrow and the name.
    static let lineGap = 2.0
    /// The space above the lines when the card is open.
    static let topInset = 12.0
    /// Room under the name before the dock.
    static let bottomInset = 4.0

    static func nameLineHeight(for size: ServerHeaderNameSize) -> Double { (size.points * 1.22).rounded(.up) }

    /// The slot the lines need, from the card's top edge to the dock.
    static func requiredHeight(for size: ServerHeaderNameSize) -> Double {
        topInset + eyebrowLineHeight + lineGap + nameLineHeight(for: size) + bottomInset
    }

    /// What to add to the original slot (an ordinary row plus 20pt); never negative.
    static func extraHeight(for size: ServerHeaderNameSize, originalSlot: Double) -> Double {
        max(0, requiredHeight(for: size) - originalSlot)
    }
}
