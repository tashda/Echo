import SwiftUI

// Round 28.14: the gutter's lane. Never rename a case's raw value: the owner's picks are saved
// under it.

enum LabQELaneHolds: String, CaseIterable {
    case everything = "LH0 · Numbers, error dot and Run arrow (today)"
    case numbers = "LH1 · The numbers only"

    var summary: String {
        self == .everything ? "The lane covers the whole gutter, so the 11pt slot for the dot and arrow sits inside it, left of the numbers."
            : "The lane wraps just the numbers with equal room on each side; the dot and arrow sit left of it, on the card."
    }
}

enum LabQELaneAlign: String, CaseIterable {
    case right = "LA0 · Right-aligned (today)"
    case centre = "LA1 · Centred in the lane"
}

enum LabQELaneHeight: String, CaseIterable {
    case short = "LT0 · Stops above the card's bottom (today)"
    case full = "LT1 · The card's height, 5pt from each edge"

    var summary: String {
        self == .short ? "Drawn inside the editor's scroll view: 5pt from the top, about 25pt short of the card's bottom."
            : "From 5pt below the card's top to 5pt above its bottom, 5pt from its left edge."
    }
}

enum LabQELaneCorner: String, CaseIterable {
    case eight = "LC0 · 8pt (today)"
    case concentric = "LC1 · Concentric with the card"
    case capsule = "LC2 · Fully round ends"

    var summary: String {
        switch self {
        case .eight: "A fixed 8pt corner."
        case .concentric: "The card's corner minus the 5pt inset, so the lane's corners follow the card's (Settings › Card Corners)."
        case .capsule: "Half the lane's width: a long pill."
        }
    }
}

enum LabQELaneFill: String, CaseIterable {
    case palette = "LF0 · The palette's grey (today)"
    case system = "LF1 · The system's quiet fill"
    case outline = "LF2 · An outline, no fill"

    var summary: String {
        switch self {
        case .palette: "Aurora #F3F4F6, Midnight #252526: fixed greys."
        case .system: "The fill macOS uses for grouped content (quaternary system fill), so it follows dark mode and Increase Contrast."
        case .outline: "A 0.5pt separator outline round the lane."
        }
    }
}
