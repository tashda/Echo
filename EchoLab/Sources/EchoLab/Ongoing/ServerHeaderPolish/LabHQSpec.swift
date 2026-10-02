import SwiftUI

/// Round 50, revision 2. A header is four independent pieces: a lead mark, how the lines of text are
/// arranged, what trails on the right, and what the colour does to the card itself. The headers
/// HQ1 to HQ32 are combinations, so there are many more than a hand-drawn set could be and they
/// differ in structure, not only in finish.
struct LabHQSpec {
    enum Lead {
        case none, dot, ring, led, engine, engineTile, monogramTile, avatarDisc
        var isLarge: Bool { self == .monogramTile || self == .avatarDisc || self == .engineTile }
    }

    enum Lines {
        case stacked, eyebrowQuiet, eyebrowTint, eyebrowRule, eyebrowDot, eyebrowSection, titleBig, titleSerif,
             crumb, sectionOver, hostMono, inline, loginLine, nameOnly, titleCountLine
    }

    enum Trail { case none, latency, count, chevronOnly, product }

    enum Surface {
        case none, wash, ruleUnder, tab, ribbon, capLine, slab, slimBanner, insetBanner, pool

        var isOnFill: Bool { self == .slimBanner || self == .insetBanner }
        var hasBackdrop: Bool { self == .wash || self == .pool }
    }

    var lead = Lead.none
    var lines = Lines.stacked
    var trail = Trail.none
    var surface = Surface.none
    var summary = ""
    /// Ignores the typeface control: the design sets its own.
    var fixedFace = false
}

extension LabHPDesign {
    /// The composition behind HQ1 to HQ32; nil for the older, hand-drawn designs.
    var spec: LabHQSpec? {
        switch self {
        case .q1: .init(lead: .dot, summary: "A 8pt dot in the colour before the name and nothing else. The smallest thing that still marks a server; the header stays one weight with the rows.")
        case .q2: .init(lead: .ring, summary: "A hollow ring: lighter than the dot, and it won't be mistaken for a status.")
        case .q3: .init(lead: .led, summary: "A dot with a soft glow, like a status light on hardware. It reads as live, so it suits the colour of a connected server.")
        case .q4: .init(lead: .dot, trail: .latency, summary: "A dot, the name, and the round trip in tabular digits on the right: a monitor's row. The product line stays under the name.")
        case .q5: .init(lines: .eyebrowQuiet, summary: "Product in 10pt tracked capitals in grey over the name. No colour at all: the test is whether type alone gives the header presence.")
        case .q6: .init(lines: .eyebrowTint, summary: "The eyebrow in the server's colour (round 50's HP4). The colour is a line of type.")
        case .q7: .init(lines: .eyebrowRule, summary: "Capitals in the colour, then a hairline of the colour running to the right edge: a section opener in a magazine.")
        case .q8: .init(lines: .eyebrowDot, summary: "A dot before the capitals, so the colour has a shape as well as a letterform.")
        case .q9: .init(lines: .eyebrowSection, summary: "The eyebrow is the product and the dock's section (SQL SERVER 2022 · DATABASES) and the name is alone under it; the line you decided in round 19, promoted.")
        case .q10: .init(lines: .eyebrowTint, summary: "As HQ6 with a 20pt name: the header is a headline.", fixedFace: true)
        case .q11: .init(lines: .titleBig, summary: "A 20pt bold rounded name with the product small under it: the title of a settings pane.", fixedFace: true)
        case .q12: .init(lines: .titleCountLine, trail: .count, summary: "A title with the number of databases on the right in a quiet capsule, as Mail's mailbox titles carry their unread count.", fixedFace: true)
        case .q13: .init(lines: .titleSerif, summary: "A 17pt New York title, the product in small capitals under it. Distinctive and quiet at once.", fixedFace: true)
        case .q14: .init(lines: .crumb, summary: "\"dkloosql10-p › Databases\": the server in grey, the section in primary. A header that says where you are.")
        case .q15: .init(lines: .sectionOver, summary: "\"Databases\" is the title and the server is the line under it in the colour. Reverses the hierarchy: you know the server from the rail, but not always the section.", fixedFace: true)
        case .q16: .init(lines: .hostMono, summary: "The name, then login@host in monospace: what you would paste to connect. Reads as a tool for people who know what a host is.")
        case .q17: .init(lead: .engine, lines: .nameOnly, trail: .product, summary: "One 28pt row like Xcode's project: the engine's symbol in the colour and the name, the product on the right in grey. Saves a line.")
        case .q18: .init(lead: .engineTile, lines: .inline, summary: "A 22pt tile with the engine's symbol in white, the name and the product in grey on the same baseline.")
        case .q19: .init(lines: .inline, summary: "No mark: the name and the product share a baseline, the product 11pt grey. Plain, and one line shorter than today.")
        case .q20: .init(lead: .monogramTile, lines: .stacked, trail: .chevronOnly, summary: "A 40pt rounded tile in the colour with the letters, the name and the product, a chevron. Echo's version of System Settings' account row; the biggest header here.", fixedFace: false)
        case .q21: .init(lead: .avatarDisc, lines: .stacked, summary: "The trail's disc at 36pt (the colour with its letters) beside the name: the header and the rail mark the server the same way.")
        case .q22: .init(lead: .engineTile, lines: .loginLine, summary: "A tile with the engine's symbol, the name, then \"sa · 12 ms\": who you are and how far away.")
        case .q23: .init(surface: .ruleUnder, summary: "Today's plain header with a 1.5pt rule of the colour under it, fading to the right, between the header and the dock.")
        case .q24: .init(surface: .tab, summary: "A small tab in the colour hangs from the card's top edge at its leading corner, with the letters in it: a file folder's index tab. The header drops 10pt.")
        case .q25: .init(surface: .ribbon, summary: "A 30pt triangle of the colour in the card's top trailing corner, clipped by its curve. Nothing in the header changes.")
        case .q26: .init(surface: .capLine, summary: "A 3pt line of the colour along the card's top edge, round the corners and fading down the sides (round 30's HD5, redrawn thinner).")
        case .q27: .init(surface: .slab, summary: "The header and the dock share one tinted glass slab inset from the card's edge; the card itself is plain.")
        case .q28: .init(lead: .avatarDisc, surface: .pool, summary: "The trail's disc at the leading edge with a soft pool of the colour behind it that fades before it reaches the name.")
        case .q29: .init(lines: .eyebrowTint, surface: .wash, summary: "Your wash with HQ6's eyebrow: the type does the work and the wash only warms it.")
        case .q30: .init(lines: .nameOnly, trail: .latency, surface: .slimBanner, summary: "A 30pt banner holding the name only, in white; the product moves under it on the card. The banner is a label, not a header.")
        case .q31: .init(lines: .eyebrowSection, surface: .insetBanner, summary: "A banner inset from the card's edge, its corners concentric, holding an eyebrow and the name in white.")
        case .q32: .init(lead: .engineTile, lines: .inline, surface: .wash, summary: "Your wash with HQ18's tile and one line.")
        default: nil
        }
    }
}
