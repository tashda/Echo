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

/// What clicking a server in the rail does while the tree is hidden.
enum CollapsedServerClickBehavior: String, Codable, CaseIterable, Sendable {
    /// Peek at the server's tree; ⌘-click or double-click reopens the tree.
    case peekCommandReopens
    case alwaysPeek
    case alwaysReopen

    var displayName: String {
        switch self {
        case .peekCommandReopens: return "Peek, ⌘-click to show the tree"
        case .alwaysPeek: return "Always peek"
        case .alwaysReopen: return "Always show the tree"
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

/// How round the editor's selection is (round 28.3: rounded, 3pt by default, a setting).
enum EditorSelectionCorners: Double, CaseIterable, Sendable {
    case square = 0
    case two = 2
    case three = 3
    case four = 4
    case six = 6

    var displayName: String {
        self == .square ? "Square" : "\(Int(rawValue)) pt"
    }
}

