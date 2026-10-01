import SwiftUI

// Round 27, revision 5: the owner loves the built bar "about 90%": it doesn't reach as far as the
// footer, and it isn't on the blur. These refine E as built (every default is what Echo does).

/// How far the horizontal bar reaches.
enum LabRSLength: String, CaseIterable {
    case grid = "L1 · The grid's width"
    case footer = "L2 · As wide as the footer"

    var summary: String {
        switch self {
        case .grid: "As built: from the row numbers to the card's right side, so it starts later than the footer's chip."
        case .footer: "It runs across the row numbers too, from the footer's left padding to its right, so its ends line up with the chip and the last pill."
        }
    }
}

/// What the rows behind the bar look like.
enum LabRSBehind: String, CaseIterable {
    case sharp = "U1 · Sharp rows"
    case blurUp = "U2 · The blur reaches past the bar"
    case glassLane = "U3 · A glass lane like the chips"
    case softBand = "U4 · A soft band of the card's colour"
    case blurOnDemand = "U5 · The blur grows while the bar shows"

    var summary: String {
        switch self {
        case .sharp: "As built: the bar sits just above the blur, over sharp rows, so it reads as laid on the content."
        case .blurUp: "The footer's blur starts a little above the bar, so the bar rests on the same soft rows as the pills: one zone, footer and bar."
        case .glassLane: "While the bar shows, it runs in a glass capsule the height of a slim chip, the same glass as the footer's pills."
        case .softBand: "While the bar shows, a band of the card's colour fades in behind it, so the rows step back and the bar stands on the card."
        case .blurOnDemand: "The blur stays where it is until you scroll; then it rises past the bar, and sinks back when the bar fades."
        }
    }

    var blursBar: Bool { self == .blurUp }
}

/// The gap between the bar's thumb and the footer's pills.
enum LabRSGap: String, CaseIterable {
    case built = "H1 · 9pt, as the pills sit above the edge"
    case snug = "H2 · 5pt, snug"
    case roomy = "H3 · 13pt, roomier"

    var points: CGFloat {
        switch self {
        case .built: LayoutTokens.Footer.pillInset
        case .snug: SpacingTokens.xxs2 - 1
        case .roomy: SpacingTokens.sm + 1
        }
    }

    var summary: String {
        switch self {
        case .built: "As built, your note: the same 9pt the pills keep above the card's edge."
        case .snug: "Closer to the pills, so bar and footer read as one block."
        case .roomy: "More air, so the bar reads as the rows' edge rather than part of the footer."
        }
    }
}

/// Whether the bar shows its track.
enum LabRSTrack: String, CaseIterable {
    case none = "T1 · No track"
    case faint = "T2 · A faint track while it shows"

    var summary: String {
        switch self {
        case .none: "As built: only the thumb, as the system's overlay bar draws it until the pointer is on it."
        case .faint: "A faint track along the bar's whole length while it shows, so you see how far it reaches and where the thumb is in it."
        }
    }
}

/// For judging: keep the bars on screen without scrolling.
enum LabRSHold: String, CaseIterable {
    case whileScrolling = "While scrolling"
    case keep = "Keep them visible"
}
