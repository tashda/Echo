import SwiftUI

/// Round 30.2's choices: where the server card's collapse chevron sits and how the card folds.
enum LabSCollapseChevron: String, CaseIterable {
    case top = "CP0 · Trailing, level with the name (today)"
    case centredText = "CP1 · Trailing, centred on name and product line"
    case centredHeader = "CP2 · Trailing, centred on the whole header with the dock"
    case leading = "CP3 · Leading, before the name, as Finder's sidebar"

    var summary: String {
        switch self {
        case .top: "The header row is top-aligned, so the chevron sits on the name's top edge, above the middle of the two lines."
        case .centredText: "The chevron lines up with the middle of the name and the product line, open or closed."
        case .centredHeader: "While open it centres on the name and the dock together; closed, on the two lines."
        case .leading: "A disclosure triangle in front of the name; the name moves right by its width."
        }
    }
}

enum LabSCollapseShows: String, CaseIterable {
    case today = "CV0 · On hover while open, always while closed (today)"
    case always = "CV1 · Always"
    case hover = "CV2 · Only on hover"
}

enum LabSCollapseMotion: String, CaseIterable {
    case today = "CM0 · Rows fade, the card snaps (today)"
    case fold = "CM1 · The card folds; rows are cut by its edge"
    case foldFade = "CM2 · The card folds while the rows fade"
    case spring = "CM3 · CM2 on the house spring"
    case rollUp = "CM4 · Rows roll up under the header as the card folds"
    case cascade = "CM5 · Rows fade one after another, bottom first, then the card folds"

    var summary: String {
        switch self {
        case .today: "The rows fade over 0.22 s but the card's background changes size at once, so for a moment the rows float over the canvas."
        case .fold: "The card's bottom edge glides up over 0.22 s and clips the rows as it goes; nothing fades."
        case .foldFade: "The edge glides up and the rows fade out together, so the last rows are gone before the edge reaches them."
        case .spring: "The same fold on Echo's house spring: it settles with a slight bounce."
        case .rollUp: "The rows slide up a little and fade as if tucked under the header; the edge follows."
        case .cascade: "The rows go one by one from the bottom, then the edge closes the gap: slower, more theatrical."
        }
    }
}

/// What a closed card keeps showing.
enum LabSCollapseClosed: String, CaseIterable {
    case header = "CC0 · The header only (today)"
    case dock = "CC1 · The header and the dock; an icon opens the card at that section"
}

/// The symbol the chevron uses.
enum LabSCollapseSymbol: String, CaseIterable {
    case turning = "CS0 · › that turns down (today)"
    case circled = "CS1 · A chevron in a soft circle"
}

struct LabSCollapseLook {
    var chevron: LabSCollapseChevron
    var shows: LabSCollapseShows
    var motion: LabSCollapseMotion
    var closed: LabSCollapseClosed
    var symbol: LabSCollapseSymbol

    static let today = LabSCollapseLook(chevron: .top, shows: .today, motion: .today, closed: .header, symbol: .turning)

    init(chevron: LabSCollapseChevron, shows: LabSCollapseShows, motion: LabSCollapseMotion, closed: LabSCollapseClosed, symbol: LabSCollapseSymbol) {
        self.chevron = chevron
        self.shows = shows
        self.motion = motion
        self.closed = closed
        self.symbol = symbol
    }

    @MainActor init(_ values: RoundValues) {
        chevron = LabSCollapseChevron(rawValue: values["chevron"]) ?? .centredText
        shows = LabSCollapseShows(rawValue: values["shows"]) ?? .today
        motion = LabSCollapseMotion(rawValue: values["motion"]) ?? .foldFade
        closed = LabSCollapseClosed(rawValue: values["closed"]) ?? .header
        symbol = LabSCollapseSymbol(rawValue: values["symbol"]) ?? .turning
    }

    /// The fold's animation for a motion choice, at the lab's speed.
    func animation(_ motion: EchoMotion) -> Animation {
        switch self.motion {
        case .today, .fold, .foldFade, .rollUp: motion.expand
        case .spring: motion.standard
        case .cascade: motion.expand.delay(0.12)
        }
    }
}
