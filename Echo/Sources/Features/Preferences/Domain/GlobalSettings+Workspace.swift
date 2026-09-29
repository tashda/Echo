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

/// Look of the SQL editor's line-number gutter.
enum EditorGutterStyle: String, Codable, CaseIterable, Sendable {
    case subtle, tinted

    var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .tinted: return "Tinted"
        }
    }
}

/// The tab bar above the cards (round 9, TB1). Classic keeps the old grey plate and separate +,
/// to revert to if the glass capsule doesn't hold up.
enum WorkspaceTabStripStyle: String, Codable, CaseIterable, Sendable {
    case glass, classic

    var displayName: String {
        switch self {
        case .glass: return "Glass"
        case .classic: return "Classic"
        }
    }
}
