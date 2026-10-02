import SwiftUI

/// Round 57, revision 3. The owner's finalists: HB3 (the menu as a floating glass pill) and HB1 (the
/// menu as a slim bar at the top), without a tint. Crucial: the animation while scrolling, and what
/// happens when an icon is clicked while scrolled down (the header comes back, the card gets taller
/// between the other cards). The lab is now a tree of cards, each header pinned from its own scroll position.
enum LabHSForm: String, CaseIterable {
    case bar = "HB1 · The menu stays as a slim bar at the top"
    case barName = "HB2 · The slim bar, with the name arriving at its left"
    case pill = "HB3 · The menu morphs into a floating pill"
    case pillName = "HB4 · One pill with the name and the menu"

    var summary: String {
        switch self {
        case .bar: "The header scrolls away; the icon menu shrinks to a slim bar in the banner's colour, rounded at the bottom, pinned to the card's top."
        case .barName: "As HB1; as the header leaves, the name fades in at the bar's left and the icons move to its right half."
        case .pill: "As the header leaves, the menu row narrows to a capsule and settles 8pt from the card's top; the rows scroll under it."
        case .pillName: "A wider capsule that carries the name on its left and the five icons on its right."
        }
    }

    var isPill: Bool { self == .pill || self == .pillName }
    var hasName: Bool { self == .barName || self == .pillName }
}

/// What the pill is made of.
enum LabHSMaterial: String, CaseIterable {
    case glass = "MT0 · Clear glass"
    case banner = "MT1 · The banner's colour, solid"
    case frosted = "MT2 · Frosted: a material with a hairline"
    case surface = "MT3 · The card's own surface, lifted on a shadow"

    var summary: String {
        switch self {
        case .glass: "The system glass: the rows blur under it. Icons in the primary colour."
        case .banner: "A solid capsule of the banner's colour, white icons: the banner shrunk."
        case .frosted: "A regular material at full strength with a 0.5pt hairline: calmer than glass, nothing shows through."
        case .surface: "The card's white, lifted on a shadow like a floating toolbar; the selected icon in the server's colour."
        }
    }
}

/// How the menu changes from the banner's row to the pinned form.
enum LabHSMorph: String, CaseIterable {
    case follows = "MP0 · It follows the scroll: every point of scrolling moves it"
    case springs = "MP1 · It springs at a threshold: 24pt of scrolling and it morphs on a spring"

    var summary: String {
        switch self {
        case .follows: "The morph is a function of the scroll position: you can stop half-way, and scrolling back reverses it exactly."
        case .springs: "A short scroll starts the morph, which then plays by itself on the spring you choose: livelier, and it finishes even if you stop."
        }
    }
}

/// What happens when an icon is clicked while the card is scrolled down.
enum LabHSClick: String, CaseIterable {
    case snap = "CK0 · The card jumps to its top, the header is there"
    case smooth = "CK1 · The list scrolls up to the card's top and the header comes back with the scroll"
    case stay = "CK2 · Nothing scrolls: the rows change under the pill"
    case reveal = "CK3 · The card jumps to its top and the header grows back from the pill on a spring"
    case fade = "CK4 · As CK1, with the old rows fading out and the new ones fading in"

    var summary: String {
        switch self {
        case .snap: "Instant: the oldest answer, and the one that feels like a bug."
        case .smooth: "A 0.5 s scroll to the card's top; because the morph follows the scroll, the pill opens back into the menu row and the banner descends as it goes."
        case .stay: "The header stays collapsed; the new section's rows replace the old ones where you are. Nothing reappears."
        case .reveal: "The scroll jumps, so the new rows are at the top at once, and the pill spreads back into the banner on its own spring: the header's return is its own animation."
        case .fade: "The scroll as CK1, and the rows cross-fade over it so the change of section reads as one thing."
        }
    }
}

/// The feel of the animations that play by themselves.
enum LabHSFeel: String, CaseIterable {
    case house = "FE0 · The house spring, a little bounce"
    case smooth = "FE1 · Smooth, no overshoot"
    case snappy = "FE2 · Snappy"

    var animation: Animation {
        switch self {
        case .house: .bouncy(duration: 0.5, extraBounce: 0.08)
        case .smooth: .smooth(duration: 0.45)
        case .snappy: .snappy(duration: 0.3)
        }
    }
}

enum LabHSPosition: String, CaseIterable {
    case centre = "PO0 · Centred"
    case leading = "PO1 · At the leading edge"
    case trailing = "PO2 · At the trailing edge"
}

/// What the next card does to the pinned menu as it arrives.
enum LabHSPush: String, CaseIterable {
    case slides = "PS0 · It is pushed up and out by the next card's top"
    case fades = "PS1 · It fades as the next card's top reaches it"
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

enum LabHSSpeed: String, CaseIterable {
    case standard = "Standard"
    case slow = "Slow (3 times, to study)"
    var scale: Double { self == .slow ? 3 : 1 }
}

struct LabHSLook {
    var form = LabHSForm.pill
    var material = LabHSMaterial.glass
    var morph = LabHSMorph.follows
    var click = LabHSClick.smooth
    var feel = LabHSFeel.house
    var position = LabHSPosition.centre
    var push = LabHSPush.slides
    var slim = LabHSSlim.medium
    var speed = LabHSSpeed.standard

    /// Echo today: the banner pinned whole, a hard edge.
    var isToday = false
    static let today = LabHSLook(isToday: true)

    @MainActor init(_ values: RoundValues) {
        form = LabHSForm(rawValue: values["form"]) ?? .pill
        material = LabHSMaterial(rawValue: values["material"]) ?? .glass
        morph = LabHSMorph(rawValue: values["morph"]) ?? .follows
        click = LabHSClick(rawValue: values["click"]) ?? .smooth
        feel = LabHSFeel(rawValue: values["feel"]) ?? .house
        position = LabHSPosition(rawValue: values["position"]) ?? .centre
        push = LabHSPush(rawValue: values["push"]) ?? .slides
        slim = LabHSSlim(rawValue: values["slim"]) ?? .medium
        speed = LabHSSpeed(rawValue: values["speed"]) ?? .standard
    }

    init(isToday: Bool) { self.isToday = isToday }
}
