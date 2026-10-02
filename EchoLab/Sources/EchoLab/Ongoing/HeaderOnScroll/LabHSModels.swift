import SwiftUI

/// Round 57. A card's list is long; its header (the banner with the name and the icon menu) is pinned
/// and the rows scroll under it, cut off by a hard edge. These are other things the header and the icon
/// menu can do as the list scrolls.
enum LabHSBehaviour: String, CaseIterable {
    case pinned = "HB0 · The whole banner stays pinned, a hard edge (Echo today)"
    case bar = "HB1 · The header scrolls away, the icon menu stays pinned as a slim bar (what you liked)"
    case barName = "HB2 · As HB1, and the server's name arrives in the bar at the left"
    case pill = "HB3 · The icon menu morphs into a floating glass pill at the top of the card"
    case pillName = "HB4 · One glass pill holding the name and the icon menu"
    case chips = "HB5 · Two glass objects: a name chip and the icon menu pill"

    var summary: String {
        switch self {
        case .pinned: "The banner is a fixed block on top; the rows are cut by its straight bottom edge, half a row visible under it."
        case .bar: "The name and the line scroll away with the rows. The icon menu shrinks from 40pt to the slim bar height and stays at the top, in the banner's colour, with rounded bottom corners."
        case .barName: "As HB1; as the header leaves, the name fades in at the bar's left and the icons move to its right half, so you always know whose list it is."
        case .pill: "As the header leaves, the menu row narrows from the card's full width to a 190pt capsule, its colour clears into glass, and it settles 8pt from the top: the rows scroll under a floating pill, with nothing else pinned."
        case .pillName: "The same morph into a wider capsule that carries the name on its left and the five icons on its right: one object, whose name never leaves."
        case .chips: "The menu pill as HB3, and the name as a small capsule of its own beside it: two glass objects."
        }
    }

    var hasName: Bool { self == .barName || self == .pillName || self == .chips }
    var isPill: Bool { self == .pill || self == .pillName || self == .chips }
}

/// What the floating pill is made of.
enum LabHSMaterial: String, CaseIterable {
    case glass = "MT0 · Clear glass"
    case tinted = "MT1 · Glass tinted with the server's colour"
    case banner = "MT2 · The banner's colour, solid"

    var summary: String {
        switch self {
        case .glass: "The system's glass: the rows blur under it. The icons are in the primary colour."
        case .tinted: "Glass with a 35% tint of the server's colour: the pill still says whose list it is."
        case .banner: "A solid pill of the banner's colour with white icons: the banner, shrunk to a capsule."
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
    var behaviour = LabHSBehaviour.pill
    var material = LabHSMaterial.glass
    var edge = LabHSEdge.round20
    var under = LabHSUnder.shadow
    var slim = LabHSSlim.medium

    static let today = LabHSLook(behaviour: .pinned, material: .banner, edge: .flat, under: .none, slim: .medium)

    @MainActor init(_ values: RoundValues) {
        behaviour = LabHSBehaviour(rawValue: values["behaviour"]) ?? .pill
        material = LabHSMaterial(rawValue: values["material"]) ?? .glass
        edge = LabHSEdge(rawValue: values["edge"]) ?? .round20
        under = LabHSUnder(rawValue: values["under"]) ?? .shadow
        slim = LabHSSlim(rawValue: values["slim"]) ?? .medium
    }

    init(behaviour: LabHSBehaviour, material: LabHSMaterial, edge: LabHSEdge, under: LabHSUnder, slim: LabHSSlim) {
        self.behaviour = behaviour; self.material = material; self.edge = edge; self.under = under; self.slim = slim
    }
}
