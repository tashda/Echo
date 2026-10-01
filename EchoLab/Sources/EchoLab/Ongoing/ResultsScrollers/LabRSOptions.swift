import SwiftUI

/// Round 27, revision 3: how the bars look.
enum LabRSBarStyle: String, CaseIterable {
    case system = "S1 · The system's bar"
    case thinLine = "S2 · A thin line"
    case softCapsule = "S3 · A soft capsule in the card's tint"
    case accent = "S4 · The accent colour"
    case glass = "S5 · A glass track"
    case groove = "S6 · A groove in the card"

    var summary: String {
        switch self {
        case .system: "Echo today: macOS's overlay bar, a 7pt thumb that widens with a track under the pointer. Drawn here to match it, since the real one sits under the footer's blur wherever it meets the footer; building this means lifting the bar above the blur."
        case .thinLine: "A 3pt line with no track, that thickens to 7pt when the pointer comes near; the quietest."
        case .softCapsule: "A 7pt capsule in a tint of the card's text colour, no track: the system's shape, the card's colour."
        case .accent: "A 5pt thumb in the accent (or the server's) colour, so the bar is tied to the window's colour."
        case .glass: "A 12pt glass capsule, like the footer's chips, with the thumb inside it: the bar becomes a piece of the footer's family."
        case .groove: "A faint full-length groove pressed into the card, with a 5pt thumb in it, like a slot the card was made with."
        }
    }

    var isSystem: Bool { self == .system }
    /// The thumb's thickness at rest and near the pointer.
    var thickness: CGFloat {
        switch self {
        case .system: 7
        case .thinLine: 3
        case .softCapsule: 7
        case .accent: 5
        case .glass: 12
        case .groove: 6
        }
    }
    var hoverThickness: CGFloat {
        switch self {
        case .system: 11
        case .thinLine: 7
        default: thickness
        }
    }
    /// The lane the bar needs, with a little air.
    var lane: CGFloat { hoverThickness + SpacingTokens.xxs * 2 }
}

/// When the bars show.
enum LabRSVisibility: String, CaseIterable {
    case whileScrolling = "V1 · While scrolling"
    case always = "V2 · Always"
    case nearBottom = "V3 · When the pointer nears the bottom"
    case overGrid = "V4 · While the pointer is over the grid"

    var summary: String {
        switch self {
        case .whileScrolling: "Echo today: they appear while you scroll and fade a moment after, as macOS does."
        case .always: "Always there, so the position is never a guess; the system bar takes its lane for good."
        case .nearBottom: "They appear when the pointer comes within reach of the bottom edge, like a control that is waiting there."
        case .overGrid: "They show while the pointer is anywhere over the grid and fade when it leaves."
        }
    }
}

/// Where the vertical bar ends.
enum LabRSVertical: String, CaseIterable {
    case aboveFooter = "R1 · Stops above the footer"
    case toBottom = "R2 · Runs down to the horizontal bar"
    case hidden = "R3 · No vertical bar"

    var summary: String {
        switch self {
        case .aboveFooter: "It ends where the footer's blur starts, so it never runs behind the pills (Echo today ends it a footer higher)."
        case .toBottom: "It runs down past the footer to meet the horizontal bar, so the two read as one frame around the rows."
        case .hidden: "No vertical bar: the row numbers already say where you are, and the trackpad scrolls."
        }
    }
}

/// Something extra that ties the position to the card.
enum LabRSExtra: String, CaseIterable {
    case none = "X0 · Nothing extra"
    case edgeFades = "X1 · Soft edges where there is more"
    case footerLine = "X2 · A position line on the footer's edge"
    case columnMap = "X3 · A column map in the footer"
    case headerLine = "X4 · A position line under the header"

    var summary: String {
        switch self {
        case .none: "Echo today."
        case .edgeFades: "The rows fade out softly at a side where more columns wait, and stop fading at the end, like the footer's blur does at the bottom."
        case .footerLine: "A 2pt line along the footer's top edge shows which part of the width you see; the footer's edge becomes the position."
        case .columnMap: "One small tick per column in the footer's gap, the visible ones lit; click one to jump there. Hidden when the gap is taken (C, F, G)."
        case .headerLine: "A 2pt line under the column header shows which part of the width you see, next to the names it describes."
        }
    }
}
