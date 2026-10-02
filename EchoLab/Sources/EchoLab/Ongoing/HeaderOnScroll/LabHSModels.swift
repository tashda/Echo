import SwiftUI

/// Round 57. A card's list is long; its header (the banner with the name and the icon menu) is pinned
/// and the rows scroll under it, cut off by a hard edge. These are other things the header and the icon
/// menu can do as the list scrolls.
enum LabHSBehaviour: String, CaseIterable {
    case pinned = "HB0 · The whole banner stays pinned, a hard edge (Echo today)"
    case rounded = "HB1 · The whole banner stays pinned, with rounded bottom corners"
    case collapse = "HB2 · The icon menu scrolls away first, then the banner shrinks to a slim bar"
    case follow = "HB3 · The icon menu scrolls away first, the banner follows after a little more"
    case away = "HB4 · Nothing is pinned: the header and the menu scroll away with the rows"
    case menu = "HB5 · The header scrolls away, the icon menu stays pinned as a slim bar"
    case chip = "HB6 · The banner scrolls away and leaves the name in a floating chip"

    var summary: String {
        switch self {
        case .pinned: "The banner is a fixed block on top; the rows are cut by its straight bottom edge, half a row visible under it."
        case .rounded: "The same block, its bottom corners rounded so the rows go under a shape rather than a line, with a soft shadow."
        case .collapse: "The menu slides up under the name first (the first 40pt of scroll); then the banner shrinks from tall to slim, its corners rounded. The name never leaves."
        case .follow: "The menu slides up under the name; the name stays 30pt more and then goes too, with the rows. The header is never pinned for long."
        case .away: "The whole card is one piece: header, menu and rows scroll together. The simplest; the name is gone when you need to know whose list it is."
        case .menu: "The name and eyebrow scroll away with the rows; the icon menu stays at the top as a slim banner, so switching section is always one click."
        case .chip: "The banner scrolls away; the name stays at the top as a small floating chip over the rows, which use the full width."
        }
    }
}

/// How the pinned part ends against the rows.
enum LabHSEdge: String, CaseIterable {
    case flat = "ED0 · A hard edge"
    case round12 = "ED1 · Corners of 12pt"
    case round20 = "ED2 · Corners of 20pt"

    var radius: CGFloat {
        switch self {
        case .flat: 0
        case .round12: 12
        case .round20: 20
        }
    }
}

enum LabHSUnder: String, CaseIterable {
    case none = "UN0 · Nothing"
    case shadow = "UN1 · A soft shadow"
    case blur = "UN2 · The rows blur under the banner"
}

enum LabHSSlim: String, CaseIterable {
    case small = "SL0 · 26pt"
    case medium = "SL1 · 32pt"
    case large = "SL2 · 40pt"

    var height: CGFloat {
        switch self {
        case .small: 26
        case .medium: 32
        case .large: 40
        }
    }
}

struct LabHSLook {
    var behaviour = LabHSBehaviour.collapse
    var edge = LabHSEdge.round20
    var under = LabHSUnder.shadow
    var slim = LabHSSlim.medium

    static let today = LabHSLook(behaviour: .pinned, edge: .flat, under: .none, slim: .medium)

    @MainActor init(_ values: RoundValues) {
        behaviour = LabHSBehaviour(rawValue: values["behaviour"]) ?? .collapse
        edge = LabHSEdge(rawValue: values["edge"]) ?? .round20
        under = LabHSUnder(rawValue: values["under"]) ?? .shadow
        slim = LabHSSlim(rawValue: values["slim"]) ?? .medium
    }

    init(behaviour: LabHSBehaviour, edge: LabHSEdge, under: LabHSUnder, slim: LabHSSlim) {
        self.behaviour = behaviour; self.edge = edge; self.under = under; self.slim = slim
    }
}
