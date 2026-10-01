import CoreGraphics
import Foundation

// Settings introduced by the canvas-and-cards redesign. See Design/01-principles.md, rule 7.

/// How fast Echo's animations run. Reduce Motion always wins over this.
enum InterfaceMotionSpeed: String, Codable, CaseIterable, Sendable {
    case standard, fast

    var displayName: String {
        switch self {
        case .standard: return "Default"
        case .fast: return "Fast"
        }
    }

    /// Multiplier applied to every animation duration.
    var durationScale: Double {
        switch self {
        case .standard: return 1
        case .fast: return 0.7
        }
    }
}

/// Space between the rail, the tree and the cards.
enum WorkspaceGutter: String, Codable, CaseIterable, Sendable {
    case compact, standard, spacious

    var displayName: String {
        switch self {
        case .compact: return "Compact (4 pt)"
        case .standard: return "Default (6 pt)"
        case .spacious: return "Spacious (8 pt)"
        }
    }

    var points: CGFloat {
        switch self {
        case .compact: return 4
        case .standard: return 6
        case .spacious: return 8
        }
    }
}

/// Corner radius of every card in the window: tree cards, editor, results, welcome and server
/// page. The default matches the macOS 27 window corner (Design/06-tokens.md).
enum WorkspaceCornerRadius: String, Codable, CaseIterable, Sendable {
    case tight, small, standard, round, extraRound

    var displayName: String {
        switch self {
        case .tight: return "10 pt"
        case .small: return "12 pt"
        case .standard: return "16 pt (Default)"
        case .round: return "20 pt"
        case .extraRound: return "26 pt"
        }
    }

    var points: CGFloat {
        switch self {
        case .tight: return 10
        case .small: return 12
        case .standard: return 16
        case .round: return 20
        case .extraRound: return 26
        }
    }
}

/// Size of the server monograms in the rail.
enum RailItemSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Default"
        case .large: return "Large"
        }
    }

    var points: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 34
        case .large: return 40
        }
    }
}

/// Look of monochrome Explorer icons.
enum SidebarMonochromeVariant: String, Codable, CaseIterable, Sendable {
    /// Expanded folders take the accent colour, so you can see your path.
    case accentOnOpen
    case pure

    var displayName: String {
        switch self {
        case .accentOnOpen: return "Accent on open folders"
        case .pure: return "Grey only"
        }
    }
}

/// Look of the SQL editor's line-number gutter (design board, 2026-09-30; Hairline from round
/// 28.2, where the owner asked for every surface in Settings). `tinted` keeps its raw value so
/// saved settings still decode; it is the full-height column.
enum EditorGutterStyle: String, Codable, CaseIterable, Sendable {
    case subtle
    case tinted
    case lane
    case hairline

    var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .tinted: return "Column"
        case .lane: return "Lane"
        case .hairline: return "Hairline"
        }
    }
}

/// The editor's line height (round 28.1, LS1), stored as a multiple of the font size: a 13pt
/// line is 17, 20 or 23pt high.
enum EditorLineHeight: Double, CaseIterable, Sendable {
    case compact = 1.3
    case comfortable = 1.55
    case relaxed = 1.75

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .relaxed: return "Relaxed"
        }
    }

    /// Any stored value (older builds offered 1.0 to 2.0) lands on the nearest name.
    static func nearest(to value: Double) -> EditorLineHeight {
        if value <= 1.25 { return .compact }
        if value <= 1.65 { return .comfortable }
        return .relaxed
    }
}

/// Round 28.15 (DC2, DS1): the corner of every mark in the editor and of the selection; round by
/// default. Replaces round 28.3's Selection Corners and 28.5's Highlight Corners.
enum EditorMarkCorners: String, Codable, CaseIterable, Sendable {
    case square, two, three, four, six, round

    var displayName: String {
        switch self {
        case .square: return "Square"
        case .two: return "2 pt"
        case .three: return "3 pt"
        case .four: return "4 pt"
        case .six: return "6 pt"
        case .round: return "Round"
        }
    }

    /// The corner radius for a mark this high.
    func radius(forHeight height: CGFloat) -> CGFloat {
        switch self {
        case .square: return 0
        case .two: return min(2, height / 2)
        case .three: return min(3, height / 2)
        case .four: return min(4, height / 2)
        case .six: return min(6, height / 2)
        case .round: return height / 2
        }
    }
}

/// Round 28.15 (DS1): how strong every mark's tint is.
enum EditorMarkStrength: String, Codable, CaseIterable, Sendable {
    case subtle, standard, strong

    var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .standard: return "Standard"
        case .strong: return "Strong"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .subtle: return 0.7
        case .standard: return 1
        case .strong: return 1.4
        }
    }
}

