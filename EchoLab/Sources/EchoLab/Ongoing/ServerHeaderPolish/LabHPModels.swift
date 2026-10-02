import SwiftUI
import AppKit

/// Round 50's headers. Round 30 asked for presence and every header got it, but they all share the
/// same recipe (a saturated gradient, white bold type, a glass capsule floating over the colour),
/// which is what makes them read as generated. These vary the ingredients one at a time: how the
/// colour is made (flat ink, lit enamel, glass, mesh), where it sits (a panel, an edge, a tile, a
/// label) and how the type is set (face, size, a line of small caps, the version as a numeral).
enum LabHPDesign: String, CaseIterable {
    case wash = "HP0 · Wash (Echo today)"
    case ink = "HP1 · Ink: a flat panel of deep colour"
    case enamel = "HP2 · Enamel: ink with a lit edge and a soft top light"
    case duotone = "HP3 · Duotone: a diagonal gradient between two hues"
    case eyebrow = "HP4 · Eyebrow: the product in small caps above the name"
    case tile = "HP5 · Tile: the engine's icon on a tinted tile"
    case spine = "HP6 · Spine: colour down the card's leading edge"
    case slab = "HP7 · Glass slab: the header on a tinted glass panel"
    case aurora = "HP8 · Aurora: a soft mesh of the colour's neighbours"
    case badge = "HP9 · Badge: an environment label beside the name"
    case numeral = "HP10 · Numeral: the version as a large mark"
    case underline = "HP11 · Underline: a short accent under the name"
    case chips = "HP12 · Chips: status, version and latency as tokens"
    // Revision 2: Echo's other four headers for comparison, then a new family of composed headers.
    case legacyPlain = "R1 · Plain (Echo's Settings)"
    case legacyBar = "R2 · Bar (Echo's Settings)"
    case legacyPlate = "R3 · Glass Plate (Echo's Settings)"
    case legacyBanner = "R4 · Banner (Echo's Settings)"
    case q1 = "HQ1 · Dot: a colour dot before the name"
    case q2 = "HQ2 · Ring: a hollow ring before the name"
    case q3 = "HQ3 · LED: a glowing dot, like a status light"
    case q4 = "HQ4 · Dot and latency on the right, like a monitor"
    case q5 = "HQ5 · Eyebrow in grey: type only, no colour"
    case q6 = "HQ6 · Eyebrow in the colour (HP4)"
    case q7 = "HQ7 · Eyebrow with a rule running out to the right"
    case q8 = "HQ8 · Eyebrow with a dot"
    case q9 = "HQ9 · Eyebrow of product and section, name below"
    case q10 = "HQ10 · Eyebrow and a large name"
    case q11 = "HQ11 · A large title, as a settings pane's"
    case q12 = "HQ12 · A title with the number of databases, as Mail's mailbox"
    case q13 = "HQ13 · A serif title with the product in small caps"
    case q14 = "HQ14 · A path: server › section"
    case q15 = "HQ15 · The section is the title; the server is the line under it"
    case q16 = "HQ16 · Name over login@host in monospace"
    case q17 = "HQ17 · Xcode's project row: an engine icon and the name on one line"
    case q18 = "HQ18 · One line: an icon tile, the name and the product beside it"
    case q19 = "HQ19 · One line: the name and the product on the same baseline"
    case q20 = "HQ20 · A profile row: a 40pt tile with the letters, two lines and a chevron"
    case q21 = "HQ21 · A profile row with the trail's disc"
    case q22 = "HQ22 · A tile, the name, and login · latency"
    case q23 = "HQ23 · A rule of colour under the header"
    case q24 = "HQ24 · An index tab hanging from the card's top edge"
    case q25 = "HQ25 · A corner ribbon"
    case q26 = "HQ26 · A line of colour along the card's top edge"
    case q27 = "HQ27 · Header and dock on one tinted glass slab"
    case q28 = "HQ28 · A pool of colour behind the leading mark"
    case q29 = "HQ29 · Wash with eyebrow type"
    case q30 = "HQ30 · A slim banner, one line"
    case q31 = "HQ31 · An inset banner with an eyebrow"
    case q32 = "HQ32 · Wash with a tile"

    var number: String { rawValue.components(separatedBy: " · ").first ?? rawValue }
    var shortName: String { rawValue.components(separatedBy: " · ").last?.components(separatedBy: ":").first ?? rawValue }

    var family: LabHPFamily {
        switch self {
        case .wash, .legacyPlain, .legacyBar, .legacyPlate, .legacyBanner: .five
        case .aurora: .soft
        case .q1, .q2, .q3, .q4: .dot
        case .q5, .q6, .q7, .q8, .q9, .q10: .eyebrow
        case .q11, .q12, .q13: .title
        case .q14, .q15, .q16: .path
        case .q17, .q18, .q19: .row
        case .q20, .q21, .q22: .profile
        case .q23, .q24, .q25, .q26, .q27, .q28: .surface
        case .q29, .q30, .q31, .q32: .remix
        case .ink, .enamel, .duotone: .fill
        case .eyebrow, .badge, .numeral, .underline, .chips: .type
        case .tile, .spine, .slab: .object
        }
    }

    /// The text sits on the colour itself, so it is white.
    var isOnFill: Bool { self == .ink || self == .enamel || self == .duotone || spec?.surface.isOnFill == true }

    /// Echo's own header setting this one stands for (R1 to R4), drawn by round 30's card.
    var legacyStyle: LabSHStyle? {
        switch self {
        case .legacyPlain: .today
        case .legacyBar: .bar
        case .legacyPlate: .plate
        case .legacyBanner: .banner
        default: nil
        }
    }

    /// Colour painted behind the header (and the dock with "Over the colour").
    var hasBackdrop: Bool {
        switch self {
        case .wash, .ink, .enamel, .duotone, .aurora: true
        default: spec?.surface.hasBackdrop == true
        }
    }

    /// A panel of colour needs room under the text; type-led headers do not.
    var padsBelow: Bool { isOnFill || self == .slab || spec?.surface == .slab }

    var summary: String {
        switch self {
        case .wash: "Echo's header today: a wash of the server's colour from the card's top edge, bold 13pt name, grey product line."
        case .ink: "One flat panel of the colour, darkened so it is calm rather than neon. No gradient: the card stays a card and the colour is a surface, like a title bar."
        case .enamel: "Ink with a 0.5pt lit edge and a faint light from above, so the panel feels like a material (a lacquered key) rather than a fill."
        case .duotone: "A gradient from the colour to its neighbour on the colour wheel, corner to corner. Brighter and friendlier than ink; the most Apple-marketing of the fills."
        case .eyebrow: "The product in 10pt tracked small caps in the colour, the name beneath it larger. No fill: colour is a line of type, as in a magazine's section opener."
        case .tile: "A 32pt rounded tile in the colour with the engine's symbol, the name and product beside it. The colour is small and exact, like an account row in Settings or Mail."
        case .spine: "A 4pt strip of the colour down the card's whole leading edge, header and rows. The header itself is plain; production stays marked as you scroll its databases."
        case .slab: "The name and product on one inset glass panel, tinted. Its corners are concentric with the card's. The only glass besides the dock."
        case .aurora: "A soft mesh of the colour and its neighbours, blurred behind the header. Rich, but quiet in the corners where the dock and rows sit."
        case .badge: "Plain header with an environment label (PROD, TEST, DEV) on the right in the colour. Says what the colour means; Echo has no environment field yet, so this would be new."
        case .numeral: "The product's version as a large rounded numeral in the colour on the right (2022, 18). Distinguishes two servers of one product at a glance."
        case .underline: "A 2.5pt accent under the name, 22pt long, in the colour. The smallest mark that still ties the header to its server."
        case .chips: "Name on top; under it small tokens: a status dot, the version, the latency. Turns the grey product line into information you can scan."
        case .legacyPlain, .legacyBar, .legacyPlate, .legacyBanner: "One of the four other headers Echo has in Settings, drawn as it is today (typeface, second line and dock controls do not apply). Judge every new one against these."
        default: spec?.summary ?? ""
        }
    }
}

enum LabHPFamily: String, CaseIterable {
    case five = "Five", dot = "Dot", eyebrow = "Eyebrow", title = "Title", path = "Path", row = "Row", profile = "Profile",
         surface = "Surface", remix = "Remix", soft = "Soft", fill = "Fill", type = "Type", object = "Object"
    var title: String {
        switch self {
        case .five: "What Echo has: wash, plain, bar, glass plate, banner (the five you said are better)"
        case .dot: "A small mark of colour before the name, nothing else"
        case .eyebrow: "A line of small caps above the name, in several voices"
        case .title: "The name as a title"
        case .path: "The header as where you are, not what the server is"
        case .row: "The header as one row, like Xcode's project"
        case .profile: "A profile row, like System Settings' account"
        case .surface: "A mark on the card itself: a rule, a tab, a ribbon, a slab"
        case .remix: "Your five, with the new type"
        case .soft: "Soft colour behind the header"
        case .fill: "A solid fill with white type"
        case .type: "No fill: the type carries the colour"
        case .object: "A tile, an edge or a panel"
        }
    }
    var designs: [LabHPDesign] { LabHPDesign.allCases.filter { $0.family == self } }
}

/// How strong the colour is. Today's headers are at Vivid; most of the "AI made" feeling is saturation.
enum LabHPStrength: String, CaseIterable {
    case muted = "CL0 · Muted"
    case standard = "CL1 · Standard"
    case vivid = "CL2 · Vivid"

    var opacityScale: Double {
        switch self {
        case .muted: 0.6
        case .standard: 1
        case .vivid: 1.4
        }
    }

    var summary: String {
        switch self {
        case .muted: "Greyed and darker: the colour is a hint. Production still reads red, but nothing shouts."
        case .standard: "The server's colour, darkened a little for fills."
        case .vivid: "The colour as the user chose it, as in round 30's banners."
        }
    }
}

enum LabHPFace: String, CaseIterable {
    case today = "TF0 · SF Bold 13 (today)"
    case semibold = "TF1 · SF Semibold 14"
    case rounded = "TF2 · SF Rounded Semibold 14"
    case serif = "TF3 · New York Semibold 15"
    case expanded = "TF4 · SF Expanded Semibold 13"
    case mono = "TF5 · SF Mono Medium 12.5"

    var font: Font {
        switch self {
        case .today: .system(size: 13, weight: .bold)
        case .semibold: .system(size: 14, weight: .semibold)
        case .rounded: .system(size: 14, weight: .semibold, design: .rounded)
        case .serif: .system(size: 15, weight: .semibold, design: .serif)
        case .expanded: .system(size: 13, weight: .semibold).width(.expanded)
        case .mono: .system(size: 12.5, weight: .medium, design: .monospaced)
        }
    }

    var summary: String {
        switch self {
        case .today: "Echo's server name today."
        case .semibold: "A step lighter and larger: bold at 13pt next to 13pt rows gives the name little to stand out with."
        case .rounded: "Friendlier; matches the rail's monograms, which are rounded."
        case .serif: "New York: the one serif on the system. Distinctive, editorial; the only header that cannot be mistaken for a row."
        case .expanded: "Wider letters: a title feel without growing taller."
        case .mono: "Server names are identifiers (dkloosql10-p), so set them like code. Aligns with the editor."
        }
    }
}

enum LabHPLine: String, CaseIterable {
    case today = "SL0 · Product · section (today)"
    case caps = "SL1 · Product in small caps"
    case host = "SL2 · Host in monospace"
    case none = "SL3 · Name only"

    var summary: String {
        switch self {
        case .today: "Grey 11pt: \"SQL Server 2022 · Databases\"."
        case .caps: "10pt tracked capitals: \"SQL SERVER 2022\". The section name drops out."
        case .host: "The host, in the editor's monospace: what you would paste into a connection string."
        case .none: "One line. The product moves to the tooltip."
        }
    }
}

/// How the dock sits against the header's colour.
enum LabHPDock: String, CaseIterable {
    case over = "DP0 · Over the colour (today)"
    case below = "DP1 · Below, on the plain card"
    case tinted = "DP2 · Below, in glass tinted with the colour"

    var summary: String {
        switch self {
        case .over: "The colour continues behind the dock, which floats on it."
        case .below: "The colour stops at the header's bottom edge; the dock sits on the card as it does in every card without a coloured header."
        case .tinted: "As DP1, and the dock's glass takes a hint of the server's colour."
        }
    }
}

/// Everything the header, backdrop and dock need.
struct LabHPLook {
    var design: LabHPDesign
    var strength: LabHPStrength
    var face: LabHPFace
    var line: LabHPLine
    var dock: LabHPDock

    static let today = LabHPLook(design: .wash, strength: .vivid, face: .today, line: .today, dock: .over)

    @MainActor init(_ values: RoundValues) {
        design = LabHPDesign(rawValue: values["design"]) ?? .ink
        strength = LabHPStrength(rawValue: values["strength"]) ?? .standard
        face = LabHPFace(rawValue: values["face"]) ?? .semibold
        line = LabHPLine(rawValue: values["line"]) ?? .today
        dock = LabHPDock(rawValue: values["dock"]) ?? .below
    }

    init(design: LabHPDesign, strength: LabHPStrength, face: LabHPFace, line: LabHPLine, dock: LabHPDock) {
        self.design = design
        self.strength = strength
        self.face = face
        self.line = line
        self.dock = dock
    }

    func with(_ design: LabHPDesign) -> LabHPLook {
        var copy = self
        copy.design = design
        return copy
    }

    func with(_ face: LabHPFace) -> LabHPLook {
        var copy = self
        copy.face = face
        return copy
    }

    /// Colour behind the dock too (only when the design paints one).
    var coversDock: Bool { dock == .over && design.hasBackdrop }
}

/// The server's colour, made for each use.
struct LabHPPalette {
    let tint: Color
    let strength: LabHPStrength

    /// A fill for white type: the colour darkened, and greyed when muted.
    var deep: Color {
        switch strength {
        case .muted: tint.mix(with: .gray, by: 0.4).mix(with: .black, by: 0.4)
        case .standard: tint.mix(with: .black, by: 0.3)
        case .vivid: tint.mix(with: .black, by: 0.08)
        }
    }

    /// The colour's neighbour on the wheel (hue +0.06), for duotone and the mesh.
    var neighbour: Color { tint.shifted(hue: 0.06) }
    var otherNeighbour: Color { tint.shifted(hue: -0.05) }

    func soft(_ opacity: Double) -> Color { tint.opacity(min(opacity * strength.opacityScale, 1)) }

    /// Type and symbols in the colour on the plain card: darkened so they hold contrast in light mode.
    var ink: Color { strength == .vivid ? tint : tint.mix(with: .gray, by: 0.15) }
}

extension Color {
    /// The same colour with its hue turned by `hue` (a fraction of the wheel).
    func shifted(hue shift: CGFloat) -> Color {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        var turned = (h + shift).truncatingRemainder(dividingBy: 1)
        if turned < 0 { turned += 1 }
        return Color(hue: Double(turned), saturation: Double(s), brightness: Double(b), opacity: Double(a))
    }
}

extension LabSHServer {
    /// The environment label the badge shows.
    var environmentLabel: String {
        switch id {
        case "prod": "PROD"
        case "test": "TEST"
        default: "DEV"
        }
    }

    /// The version without the product: "2022", "18".
    var versionNumeral: String { product.components(separatedBy: " ").last ?? product }

    /// The product without its version, in capitals.
    var productCaps: String { product.uppercased() }
}
