import Foundation

/// What a user can change about the title banner header (round 53, level LV2): the name's
/// typeface and size, the line above the name, how the banner ends, and the type's colour. One
/// setting for every server card (SC0). Weight, alignment, spacing, fill and icon size are not
/// offered: they stay Echo's.
nonisolated struct ServerHeaderLook: Codable, Hashable, Sendable {
    var typeface: ServerHeaderTypeface = .system
    var nameSize: ServerHeaderNameSize = .standard
    var eyebrow: ServerHeaderEyebrowLine = .section
    var spacing: ServerHeaderSpacing = .tight
    var edge: ServerHeaderEdge = .hairline
    var textColor: ServerHeaderTextColor = .white

    init() {}

    /// Unknown or missing values (older or newer settings) keep Echo's choice. A look saved before
    /// round 58 has no `spacing`: if its size and line are the old defaults (Medium, 22pt, and the
    /// section) it was never chosen, so it moves to the new defaults once (18pt, the section,
    /// tight); any other saved choice is kept. Saving writes `spacing`, so this runs once.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeface = (try? container.decodeIfPresent(ServerHeaderTypeface.self, forKey: .typeface)) ?? .system
        let savedSize = try? container.decodeIfPresent(ServerHeaderNameSize.self, forKey: .nameSize)
        eyebrow = (try? container.decodeIfPresent(ServerHeaderEyebrowLine.self, forKey: .eyebrow)) ?? .section
        spacing = (try? container.decodeIfPresent(ServerHeaderSpacing.self, forKey: .spacing)) ?? .tight
        nameSize = Self.migratedNameSize(saved: savedSize, eyebrow: eyebrow, hasSpacing: container.contains(.spacing))
        edge = (try? container.decodeIfPresent(ServerHeaderEdge.self, forKey: .edge)) ?? .hairline
        textColor = (try? container.decodeIfPresent(ServerHeaderTextColor.self, forKey: .textColor)) ?? .white
    }

    /// The size to use: the saved one, except an old default (Medium, with the section over it,
    /// saved before spacing existed) which moves to the new default.
    static func migratedNameSize(saved: ServerHeaderNameSize?, eyebrow: ServerHeaderEyebrowLine, hasSpacing: Bool) -> ServerHeaderNameSize {
        guard let saved else { return .standard }
        if !hasSpacing, saved == .large, eyebrow == .section { return .standard }
        return saved
    }
}

nonisolated enum ServerHeaderTypeface: String, Codable, CaseIterable, Sendable {
    case system, rounded, serif, monospaced, expanded

    var displayName: String {
        switch self {
        case .system: "System"
        case .rounded: "Rounded"
        case .serif: "Serif (New York)"
        case .monospaced: "Monospaced"
        case .expanded: "Expanded"
        }
    }
}

/// The name's size (round 58): 12 to 26pt, 18pt by default. Settings saved before round 58 hold
/// `small` (18pt), `medium` (22pt) or `large` (26pt); they still decode, to the same sizes.
nonisolated enum ServerHeaderNameSize: String, Codable, CaseIterable, Sendable {
    case tiny = "pt12", extraSmall = "pt14", small = "pt16", standard = "pt18", large = "pt22", extraLarge = "pt26"

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "small": self = .standard
        case "medium": self = .large
        case "large": self = .extraLarge
        default:
            guard let size = Self(rawValue: value) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown size \(value)"))
            }
            self = size
        }
    }

    var points: Double {
        switch self {
        case .tiny: 12
        case .extraSmall: 14
        case .small: 16
        case .standard: 18
        case .large: 22
        case .extraLarge: 26
        }
    }

    var displayName: String {
        switch self {
        case .tiny: "Tiny (12pt)"
        case .extraSmall: "Extra Small (14pt)"
        case .small: "Small (16pt)"
        case .standard: "Standard (18pt)"
        case .large: "Large (22pt)"
        case .extraLarge: "Extra Large (26pt)"
        }
    }
}

/// The room around the lines on the banner (round 58, DN0 and DN1): Tight puts 6pt above the
/// first line, Standard 10pt.
nonisolated enum ServerHeaderSpacing: String, Codable, CaseIterable, Sendable {
    case tight, standard

    /// The space above the first line.
    var topInset: Double { self == .tight ? 6 : 10 }
    /// The extra room between the name and the dock, over Tight.
    var dockGap: Double { self == .tight ? 0 : 4 }

    var displayName: String {
        switch self {
        case .tight: "Tight"
        case .standard: "Standard"
        }
    }
}

/// The line of small capitals over the server's name.
nonisolated enum ServerHeaderEyebrowLine: String, Codable, CaseIterable, Sendable {
    case section, engine, engineAndSection, sectionAtRight, none

    /// True when the line sits over the name (taking a row of its own); the right-hand section
    /// shares the name's row, and None has no line.
    var isOverName: Bool { self == .section || self == .engine || self == .engineAndSection }

    var displayName: String {
        switch self {
        case .section: "The Section"
        case .engine: "The Engine"
        case .engineAndSection: "The Engine and the Section"
        case .sectionAtRight: "The Section at the Right"
        case .none: "Nothing Above the Name"
        }
    }
}

/// How the banner ends against the card's rows.
nonisolated enum ServerHeaderEdge: String, Codable, CaseIterable, Sendable {
    case sharp, hairline, softFade, frostedFade

    var displayName: String {
        switch self {
        case .sharp: "Sharp"
        case .hairline: "Sharp with a Hairline of Light"
        case .softFade: "Soft Fade"
        case .frostedFade: "Frosted Fade"
        }
    }
}

nonisolated enum ServerHeaderTextColor: String, Codable, CaseIterable, Sendable {
    case white, automatic

    var displayName: String {
        switch self {
        case .white: "Always White"
        case .automatic: "Automatic"
        }
    }
}
