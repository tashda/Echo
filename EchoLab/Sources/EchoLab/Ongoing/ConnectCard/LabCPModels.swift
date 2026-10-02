import SwiftUI

/// Round 56. The connect button is now a glass circle of its own under the pills. Round 52's card
/// grew out of the connected pill; these are the ways it can open from the circle instead, what it
/// holds when the connected servers are in plain sight beside it, what the circle does meanwhile,
/// and how it is dismissed (a click outside, Escape and, if wanted, a close button).
enum LabCPPresentation: String, CaseIterable {
    case grows = "PR0 · The circle grows into the card (one liquid glass shape)"
    case scales = "PR1 · The card opens from the circle, to its right, on a spring"
    case merge = "PR2 · The pills melt into one tall panel (round 52, adapted)"
    case drawer = "PR3 · A drawer beside the trail, the height of the window"
    case palette = "PR4 · A palette in the middle of the window"
    case popover = "PR5 · A system popover with an arrow, to the circle's right"

    var summary: String {
        switch self {
        case .grows: "The circle and the card are one glass shape (glass effect ID): the card swells from the circle and shrinks back into it. Its bottom-left corner stays at the circle."
        case .scales: "The card appears to the right of the circle, level with its bottom edge, growing from that corner on a spring; no morph."
        case .merge: "Round 52's behaviour: the pills and the circle fade into one panel that widens from the trail, with the servers lying in a row on top."
        case .drawer: "A full-height glass panel next to the trail, over the tree; room for forty connections."
        case .palette: "A command palette in the middle of the window with a light scrim; furthest from the button."
        case .popover: "The system's own popover, arrow pointing at the circle. Familiar, and dismisses on a click outside by itself."
        }
    }
}

/// What the card holds.
enum LabCPContent: String, CaseIterable {
    case header = "CD0 · A row of the connected servers, the three actions and a close button; then the list (as built)"
    case search = "CD1 · The search field with the three actions beside it; then the list"

    var summary: String {
        switch self {
        case .header: "As round 52 built it. With the trail beside the card, the row of connected servers repeats what is a few points to its left."
        case .search: "Nothing repeated: the search field leads, the three icons sit in it, and the list holds saved connections only."
        }
    }
}

/// What the circle does while the card is open.
enum LabCPButton: String, CaseIterable {
    case morphs = "CB0 · It becomes the close button: the rack turns to an ×"
    case stays = "CB1 · It stays a rack, pressed: a soft fill under it"
    case hidden = "CB2 · It gives way to the card and fades"

    var summary: String {
        switch self {
        case .morphs: "The glyph swaps with a symbol effect and the circle is the close button; the card needs none of its own."
        case .stays: "The circle stays where it is with a pressed look; pressing it again closes."
        case .hidden: "The card covers the circle's place; the card has its own close button."
        }
    }
}

/// What the other pills do while the card is open.
enum LabCPOthers: String, CaseIterable {
    case stay = "OT0 · They stay as they are"
    case dim = "OT1 · They step back to 45%"
    case fade = "OT2 · They fade away"

    var summary: String {
        switch self {
        case .stay: "The trail stays usable: you can switch server with the card open."
        case .dim: "They dim, so the card is the one live thing, and are still there."
        case .fade: "Only the card and the circle remain."
        }
    }
}

enum LabCPScrim: String, CaseIterable {
    case none = "SC0 · None"
    case light = "SC1 · A light scrim over the tree"
}

enum LabCPClose: String, CaseIterable {
    case yes = "XB0 · A close button in the card as well"
    case no = "XB1 · No button: a click outside, Escape or the circle"
}

struct LabCPLook {
    var presentation = LabCPPresentation.grows
    var content = LabCPContent.search
    var button = LabCPButton.morphs
    var others = LabCPOthers.stay
    var scrim = LabCPScrim.none
    var close = LabCPClose.yes

    static let today = LabCPLook(presentation: .merge, content: .header, button: .hidden, others: .fade, scrim: .none, close: .yes)

    @MainActor init(_ values: RoundValues) {
        presentation = LabCPPresentation(rawValue: values["presentation"]) ?? .grows
        content = LabCPContent(rawValue: values["content"]) ?? .search
        button = LabCPButton(rawValue: values["button"]) ?? .morphs
        others = LabCPOthers(rawValue: values["others"]) ?? .stay
        scrim = LabCPScrim(rawValue: values["scrim"]) ?? .none
        close = LabCPClose(rawValue: values["close"]) ?? .yes
    }

    init(presentation: LabCPPresentation, content: LabCPContent, button: LabCPButton, others: LabCPOthers, scrim: LabCPScrim, close: LabCPClose) {
        self.presentation = presentation; self.content = content; self.button = button
        self.others = others; self.scrim = scrim; self.close = close
    }

    /// The list's look: round 52's, with the actions in the header row or in the search field.
    var listLook: LabCMLook {
        var look = LabCMLook(presentation: .rail, morph: .none, content: .search, footer: .bar, count: .some)
        look.opened = content == .header ? .header : .search
        look.close = close == .yes ? .plain : .none
        return look
    }
}
