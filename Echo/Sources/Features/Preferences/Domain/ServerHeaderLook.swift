import Foundation

/// What a user can change about the title banner header (round 53, level LV2): the name's
/// typeface and size, the line above the name, how the banner ends, and the type's colour. One
/// setting for every server card (SC0). Weight, alignment, spacing, fill and icon size are not
/// offered: they stay Echo's.
nonisolated struct ServerHeaderLook: Codable, Hashable, Sendable {
    var typeface: ServerHeaderTypeface = .system
    var nameSize: ServerHeaderNameSize = .medium
    var eyebrow: ServerHeaderEyebrowLine = .section
    var edge: ServerHeaderEdge = .hairline
    var textColor: ServerHeaderTextColor = .white

    init() {}

    /// Unknown or missing values (older or newer settings) keep Echo's choice.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeface = (try? container.decodeIfPresent(ServerHeaderTypeface.self, forKey: .typeface)) ?? .system
        nameSize = (try? container.decodeIfPresent(ServerHeaderNameSize.self, forKey: .nameSize)) ?? .medium
        eyebrow = (try? container.decodeIfPresent(ServerHeaderEyebrowLine.self, forKey: .eyebrow)) ?? .section
        edge = (try? container.decodeIfPresent(ServerHeaderEdge.self, forKey: .edge)) ?? .hairline
        textColor = (try? container.decodeIfPresent(ServerHeaderTextColor.self, forKey: .textColor)) ?? .white
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

nonisolated enum ServerHeaderNameSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    var points: Double {
        switch self {
        case .small: 18
        case .medium: 22
        case .large: 26
        }
    }

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
}

/// The line of small capitals over the server's name.
nonisolated enum ServerHeaderEyebrowLine: String, Codable, CaseIterable, Sendable {
    case section, engine, engineAndSection, none

    var displayName: String {
        switch self {
        case .section: "The Section"
        case .engine: "The Engine"
        case .engineAndSection: "The Engine and the Section"
        case .none: "None"
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
