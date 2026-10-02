import SwiftUI

/// Round 59. A card's menu pill is pinned at the top while its rows scroll; the next card arrives from
/// below. These are the ways the pill and the cards can hand over.
enum LabHOHandover: String, CaseIterable {
    case push = "HO0 · The pill is pushed up and out by the next card's top (round 57 as built)"
    case fade = "HO1 · The pill fades before the next card reaches it"
    case overtaken = "HO2 · The next card slides over the pill: the pill is covered by its top edge"
    case squash = "HO3 · The pill is pushed out and shrinks and fades as it goes"
    case chip = "HO4 · The pill shrinks to a name chip as the next card nears, then the card covers it"

    var summary: String {
        switch self {
        case .push: "A sticky header: the pill keeps its shape and is carried up by the next card's top edge, a few points ahead of it."
        case .fade: "The pill dissolves over 40pt before the next card's top reaches it: nothing ever touches the next card."
        case .overtaken: "The pill stays pinned and the next card rises over it, its top edge cutting the pill off: the card is on top, as if it were stacked over the last."
        case .squash: "As HO0, with the pill scaling to 82% and fading to 30% while it is pushed: it leaves rather than gets shoved."
        case .chip: "Over the last 90pt before the next card, the pill narrows to a 130pt chip holding only the name, which the next card then covers: the card you are leaving is named as it goes."
        }
    }
}

enum LabHOCards: String, CaseIterable {
    case apart = "CD0 · Separate, an 8pt gap between cards (as built)"
    case overlap = "CD1 · The next card overlaps the last by 14pt, with a shadow"

    var summary: String {
        switch self {
        case .apart: "Each card is a card on the canvas with a gap."
        case .overlap: "Cards stack: the later one lies over the bottom of the earlier one with a soft shadow along its top edge, so it reads as arriving over it."
        }
    }
}
