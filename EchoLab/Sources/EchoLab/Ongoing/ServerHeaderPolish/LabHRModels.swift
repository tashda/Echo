import SwiftUI

/// Round 50, revision 3: a clean start. The owner's favourite header is the banner (R4); the open
/// questions are how the icon menu (the dock) sits on a coloured surface, or on a plain card without
/// looking like a white strip pasted on top; HQ10's large name with an eyebrow that does not
/// say the database version; and HQ30's slim banner showing the selected section on the right and
/// reaching down behind the dock.
enum LabHRForm: String, CaseIterable {
    case plain = "F1 · Plain (Echo's Settings)"
    case wash = "F2 · Wash (Echo's default)"
    case banner = "F3 · Banner (Echo's Settings)"
    case slim = "F4 · Slim banner: one line, the section on the right"
    case bannerTitle = "F5 · Banner with an eyebrow over a large name"
    case inset = "F6 · Inset banner, concentric with the card"
    case plainTitle = "F7 · Eyebrow over a large name on the plain card"
    case washTitle = "F8 · Eyebrow over a large name on the wash"

    var number: String { rawValue.components(separatedBy: " · ").first ?? rawValue }

    enum Surface { case none, wash, banner, inset }

    var surface: Surface {
        switch self {
        case .plain, .plainTitle: .none
        case .wash, .washTitle: .wash
        case .banner, .bannerTitle, .slim: .banner
        case .inset: .inset
        }
    }

    /// White type on a solid fill.
    var isOnFill: Bool { surface == .banner || surface == .inset }
    var hasLargeName: Bool { self == .bannerTitle || self == .plainTitle || self == .washTitle }

    var summary: String {
        switch self {
        case .plain: "Bold 13pt name and a grey product line on the plain card."
        case .wash: "A wash of the server's colour from the card's top edge. Echo's default today."
        case .banner: "The header filled with the server's colour, white type. Your favourite today."
        case .slim: "A 30pt banner holding the name alone, in white. The product moves to the tooltip. What shows on the right, and how far the colour reaches, are the controls below."
        case .bannerTitle: "The banner, with a line of small capitals over a 20pt name (HQ10's type on the banner). What the eyebrow says is a control."
        case .inset: "A banner panel 5pt in from the card's edges, its corners concentric with the card's; with Reach set to the dock, the dock sits inside it."
        case .plainTitle: "HQ10 as it was: the eyebrow in the colour over a 20pt name, on the plain card."
        case .washTitle: "The same on the wash."
        }
    }
}

/// How the icon menu sits against the card or the colour.
enum LabHRDock: String, CaseIterable {
    case glass = "D0 · Glass capsule (Echo today)"
    case tinted = "D1 · Glass tinted with the colour"
    case flat = "D2 · A flat translucent capsule"
    case pill = "D3 · No capsule: the selected icon in a pill"
    case recessed = "D4 · A recessed capsule, the selected icon raised"
    case underline = "D5 · No capsule: a line under the selected icon"

    var summary: String {
        switch self {
        case .glass: "Glass over whatever is behind: on a banner it reads as a frosted white strip; on the plain card it is almost invisible."
        case .tinted: "The glass takes the colour: on a banner it darkens into it, on a card it picks up a hint of it."
        case .flat: "No blur: a capsule of white at 16% on the banner, of grey at 6% on a card. Calm, and it never goes white."
        case .pill: "The icons sit straight on the surface with nothing around them; the selected one gets a pill (white on a banner, the server's colour at 18% on a card), which slides between icons."
        case .recessed: "A capsule cut into the surface (black at 20% on a banner, grey on a card); the selected icon is a raised disc, as the trail's selection is."
        case .underline: "Icons on the surface; a 2pt line under the selected one, as a tab bar. The lightest of the six."
        }
    }
}

/// What the header shows on its right, besides the chevron.
enum LabHRRight: String, CaseIterable {
    case none = "RT0 · Nothing"
    case section = "RT1 · The selected section's name"
    case icon = "RT2 · The selected section's icon"
    case both = "RT3 · The icon and the name"

    var summary: String {
        switch self {
        case .none: "Today's header: the name and the product line."
        case .section: "\"Databases\", \"Security\": the icon menu is icons only, so the name says what the selected one is."
        case .icon: "A small disc with the icon of the selected section, repeating the dock."
        case .both: "The icon in its disc, then the name."
        }
    }
}

/// How far the colour reaches.
enum LabHRReach: String, CaseIterable {
    case header = "RC0 · The header only"
    case dock = "RC1 · Down through the icon menu"

    var summary: String {
        switch self {
        case .header: "The colour stops under the name; the icon menu sits on the card."
        case .dock: "The colour continues behind the icon menu, so the header and the menu are one surface."
        }
    }
}

/// What the line over a large name says (F5, F7, F8).
enum LabHREyebrow: String, CaseIterable {
    case engine = "EY0 · The engine: SQL SERVER"
    case section = "EY1 · The selected section: DATABASES"
    case engineSection = "EY2 · The engine and the section: SQL SERVER · DATABASES"
    case version = "EY3 · The product and its version (HQ10): SQL SERVER 2017"
    case none = "EY4 · No eyebrow"

    var summary: String {
        switch self {
        case .engine: "Says what kind of server it is and nothing that changes: SQL SERVER, POSTGRESQL, MYSQL."
        case .section: "The eyebrow is the dock's current section and changes as you switch."
        case .engineSection: "Both: the engine, a dot, the section."
        case .version: "As HQ10 had it: the version is the part you doubted anyone wants."
        case .none: "The large name on its own, with today's product line under it."
        }
    }
}

/// How the colour is mixed.
enum LabHRTone: String, CaseIterable {
    case echo = "CL0 · The server's colour, as the banner draws it"
    case deeper = "CL1 · Deeper: darkened a third"

    var summary: String {
        switch self {
        case .echo: "Exactly Echo's banner today: the colour at 92% to 100% from top to bottom."
        case .deeper: "The same colour darkened, so white type and the icon menu hold more contrast."
        }
    }
}

/// The selected icon's weight, size and fill.
enum LabHRIcon: String, CaseIterable {
    case semibold14 = "IC0 · Semibold 14, outline (what you saw)"
    case bold15 = "IC1 · Bold 15, outline"
    case filled14 = "IC2 · Semibold 14, filled symbol"
    case filled15 = "IC3 · Bold 15, filled symbol"
    case heavy16 = "IC4 · Heavy 16, filled symbol"
    case contrast = "IC5 · Bold 15, filled, the other icons at half strength"

    var font: Font {
        switch self {
        case .semibold14: .system(size: 14, weight: .semibold)
        case .bold15, .contrast: .system(size: 15, weight: .bold)
        case .filled14: .system(size: 14, weight: .semibold)
        case .filled15: .system(size: 15, weight: .bold)
        case .heavy16: .system(size: 16, weight: .heavy)
        }
    }

    var isFilled: Bool { self != .semibold14 && self != .bold15 }
    var othersOpacity: Double { self == .contrast ? 0.5 : 0.78 }
    var summary: String {
        switch self {
        case .semibold14: "The selected icon one weight above the others, as you saw it."
        case .bold15: "A step bigger and bold: the weight carries the selection."
        case .filled14: "The filled version of the symbol, same size."
        case .filled15: "Filled and bold at 15pt."
        case .heavy16: "The heaviest: filled, 16pt."
        case .contrast: "As IC3, and the other four step back to half strength so the selected one stands out."
        }
    }
}

/// The shape and weight of what sits behind the selected icon.
enum LabHRPill: String, CaseIterable {
    case wide = "PL0 · A wide capsule, the icon's whole cell"
    case compact = "PL1 · A compact capsule around the icon"
    case disc = "PL2 · A disc"
    case square = "PL3 · A rounded square"
    case raised = "PL4 · A compact capsule, raised on a shadow"
    case ring = "PL5 · A compact capsule, outline only"
    case glass = "PL6 · A compact capsule of glass"

    var summary: String {
        switch self {
        case .wide: "Fills the cell: the most visible, and the pill touches its neighbours at five icons."
        case .compact: "42 by 24pt around the icon: clear space on both sides."
        case .disc: "A 28pt circle, as the trail's selection disc."
        case .square: "A 30 by 26pt rounded square, like a toolbar button's selected state."
        case .raised: "The compact capsule with a soft shadow under it: the selection sits above the surface."
        case .ring: "No fill; a 1.5pt outline. The lightest, the one that cannot be missed least."
        case .glass: "A compact capsule of glass over the banner: the system's own selection."
        }
    }
}

/// The large name (F5, F7, F8).
enum LabHRName: String, CaseIterable {
    case bold20 = "NT0 · SF Bold 20 (what you saw)"
    case semibold22 = "NT1 · SF Semibold 22"
    case heavy22 = "NT2 · SF Heavy 22"
    case rounded22 = "NT3 · SF Rounded Bold 22"
    case serif22 = "NT4 · New York Bold 22"
    case expanded20 = "NT5 · SF Expanded Semibold 20"
    case light26 = "NT6 · SF Light 26"
    case mono18 = "NT7 · SF Mono Semibold 18"
    case tight24 = "NT8 · SF Bold 24, tight"
    case condensed24 = "NT9 · SF Condensed Bold 24"

    var font: Font {
        switch self {
        case .bold20: .system(size: 20, weight: .bold)
        case .semibold22: .system(size: 22, weight: .semibold)
        case .heavy22: .system(size: 22, weight: .heavy)
        case .rounded22: .system(size: 22, weight: .bold, design: .rounded)
        case .serif22: .system(size: 22, weight: .bold, design: .serif)
        case .expanded20: .system(size: 20, weight: .semibold).width(.expanded)
        case .light26: .system(size: 26, weight: .light)
        case .mono18: .system(size: 18, weight: .semibold, design: .monospaced)
        case .tight24: .system(size: 24, weight: .bold)
        case .condensed24: .system(size: 24, weight: .bold).width(.condensed)
        }
    }

    var tracking: CGFloat { self == .tight24 ? -0.6 : (self == .light26 ? -0.3 : 0) }
}

/// The eyebrow over the name.
enum LabHREyebrowStyle: String, CaseIterable {
    case standard = "EF0 · 10pt semibold, tracked (what you saw)"
    case bold = "EF1 · 11pt bold, wide tracking"
    case small = "EF2 · 9pt heavy, widest tracking, fainter"
    case sentence = "EF3 · 11pt medium, sentence case"
    case mono = "EF4 · 10pt monospaced, tracked"
    case rounded = "EF5 · 10.5pt rounded semibold, brighter"

    var font: Font {
        switch self {
        case .standard: .system(size: 10, weight: .semibold)
        case .bold: .system(size: 11, weight: .bold)
        case .small: .system(size: 9, weight: .heavy)
        case .sentence: .system(size: 11, weight: .medium)
        case .mono: .system(size: 10, weight: .medium, design: .monospaced)
        case .rounded: .system(size: 10.5, weight: .semibold, design: .rounded)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .standard: 0.9
        case .bold: 1.3
        case .small: 1.8
        case .sentence: 0
        case .mono: 1.0
        case .rounded: 0.6
        }
    }

    var isCaps: Bool { self != .sentence }
    var opacity: Double { self == .small ? 0.7 : (self == .rounded ? 0.95 : 0.82) }
}

/// How the banner ends against the card.
enum LabHREdge: String, CaseIterable {
    case soft = "ED0 · A soft fade into the card (Echo today)"
    case sharp = "ED1 · A sharp edge"
    case hairline = "ED2 · A sharp edge with a hairline of light"
    case shortFade = "ED3 · A short fade, 14pt"
    case frosted = "ED4 · A frosted fade: the banner blurs into the card"
    case lifted = "ED5 · A sharp edge lifted on a soft shadow"
    case rounded = "ED6 · Rounded bottom corners"
    case curve = "ED7 · A gentle curve downward"
    case slanted = "ED8 · A slanted edge"

    var summary: String {
        switch self {
        case .soft: "The colour fades to clear over the last third of the banner, behind the icon menu."
        case .sharp: "The banner stops in a straight line (R4 as it is)."
        case .hairline: "Sharp, with a 0.5pt line of white at 35% along the bottom: the edge catches the light."
        case .shortFade: "Sharp for most of the banner, softened over its last 14pt."
        case .frosted: "A material blurs the banner's last 36pt into the card instead of a plain fade."
        case .lifted: "A sharp edge with a soft shadow: the banner sits above the rows."
        case .rounded: "The banner's bottom corners are 18pt round, so it reads as a panel hung from the top."
        case .curve: "The bottom edge bows down 10pt in the middle."
        case .slanted: "The bottom edge rises 10pt to the left, like a banner cut on a diagonal."
        }
    }

    /// Room under the dock that the shape needs.
    var extraBottom: CGFloat {
        switch self {
        case .curve, .slanted: 10
        case .rounded: 4
        default: 0
        }
    }
}

/// A colour a user could pick for a server: one for light, one for dark, so it holds in both.
enum LabHRColour: String, CaseIterable {
    case sample = "The sample's own"
    case crimson = "Crimson", vermilion = "Vermilion", tangerine = "Tangerine", amber = "Amber", gold = "Gold"
    case lime = "Lime", fern = "Fern", emerald = "Emerald", jade = "Jade", teal = "Teal"
    case cyan = "Cyan", sky = "Sky", azure = "Azure", cobalt = "Cobalt", indigo = "Indigo"
    case violet = "Violet", orchid = "Orchid", magenta = "Magenta", rose = "Rose", coral = "Coral"
    case terracotta = "Terracotta", sand = "Sand", moss = "Moss", spruce = "Spruce", steel = "Steel"
    case slate = "Slate", graphite = "Graphite", plum = "Plum", burgundy = "Burgundy", navy = "Navy"

    /// Light and dark appearance as hex.
    private var hex: (light: UInt32, dark: UInt32)? {
        switch self {
        case .sample: nil
        case .crimson: (0xC62F3B, 0xFF5A67)
        case .vermilion: (0xE2492B, 0xFF7452)
        case .tangerine: (0xEF7A1A, 0xFF9A3D)
        case .amber: (0xE5A100, 0xFFC433)
        case .gold: (0xB8962E, 0xE3C45B)
        case .lime: (0x7DAF1C, 0xA6D94A)
        case .fern: (0x3F9B4B, 0x5FCB70)
        case .emerald: (0x0E9F6E, 0x34D399)
        case .jade: (0x14917E, 0x3EC9B2)
        case .teal: (0x0F8B94, 0x3FC0CB)
        case .cyan: (0x1A9FD1, 0x4CC9F5)
        case .sky: (0x3B8FE8, 0x6FB3FF)
        case .azure: (0x2563EB, 0x5B8DFF)
        case .cobalt: (0x3446C9, 0x6C7CFF)
        case .indigo: (0x5B3FD1, 0x8B7BFF)
        case .violet: (0x8A3FD1, 0xB27BFF)
        case .orchid: (0xB03FC9, 0xD77BF0)
        case .magenta: (0xD1318F, 0xF56BBA)
        case .rose: (0xE0446A, 0xFF7C9A)
        case .coral: (0xF0605D, 0xFF8A85)
        case .terracotta: (0xB5563A, 0xE08A6B)
        case .sand: (0xA88B5E, 0xD6BD8E)
        case .moss: (0x6B7F3A, 0xA1B86A)
        case .spruce: (0x2F6B55, 0x5FA98C)
        case .steel: (0x4F6F8F, 0x8FB0D0)
        case .slate: (0x5B6575, 0x9AA5B8)
        case .graphite: (0x3A3F47, 0x8A929E)
        case .plum: (0x6B2E5E, 0xB56AA6)
        case .burgundy: (0x7A1F32, 0xC45A70)
        case .navy: (0x1D2F5C, 0x5C78C4)
        }
    }

    func color(_ scheme: ColorScheme) -> Color? {
        guard let hex else { return nil }
        let value = scheme == .dark ? hex.dark : hex.light
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    static var palette: [LabHRColour] { allCases.filter { $0 != .sample } }
}

struct LabHRLook {
    var form: LabHRForm
    var dock: LabHRDock
    var right: LabHRRight
    var reach: LabHRReach
    var eyebrow: LabHREyebrow
    var tone: LabHRTone
    var icon = LabHRIcon.semibold14
    var pill = LabHRPill.wide
    var name = LabHRName.bold20
    var eyebrowStyle = LabHREyebrowStyle.standard
    var edge = LabHREdge.soft
    var colour = LabHRColour.sample

    static let today = LabHRLook(form: .wash, dock: .glass, right: .none, reach: .dock, eyebrow: .version, tone: .echo)

    @MainActor init(_ values: RoundValues) {
        // Picked by the owner in revision 3: right side nothing, colour down through the icon menu,
        // the eyebrow says the section, the banner's own colour.
        form = LabHRForm(rawValue: values["form"]) ?? .bannerTitle
        dock = LabHRDock(rawValue: values["dock"]) ?? .pill
        right = .none
        reach = .dock
        eyebrow = .section
        tone = .echo
        icon = LabHRIcon(rawValue: values["icon"]) ?? .filled15
        pill = LabHRPill(rawValue: values["pill"]) ?? .compact
        name = LabHRName(rawValue: values["name"]) ?? .bold20
        eyebrowStyle = LabHREyebrowStyle(rawValue: values["eyebrowStyle"]) ?? .standard
        edge = LabHREdge(rawValue: values["edge"]) ?? .hairline
        colour = LabHRColour(rawValue: values["colour"]) ?? .sample
    }

    init(form: LabHRForm, dock: LabHRDock, right: LabHRRight, reach: LabHRReach, eyebrow: LabHREyebrow, tone: LabHRTone) {
        self.form = form
        self.dock = dock
        self.right = right
        self.reach = reach
        self.eyebrow = eyebrow
        self.tone = tone
    }

    func with(form: LabHRForm? = nil, dock: LabHRDock? = nil, colour: LabHRColour? = nil) -> LabHRLook {
        var copy = self
        if let form { copy.form = form }
        if let dock { copy.dock = dock }
        if let colour { copy.colour = colour }
        return copy
    }

    /// The server's colour: the chosen palette colour in this appearance, or the sample's own.
    func tint(for server: LabSHServer, scheme: ColorScheme) -> Color {
        colour.color(scheme) ?? server.color
    }

    /// The colour reaches the dock only where there is a coloured surface to reach with.
    var dockOnColour: Bool { reach == .dock && form.isOnFill }
}

/// The server's colour for one use.
struct LabHRPalette {
    let tint: Color
    let tone: LabHRTone

    /// The banner's colour: Echo's, or darkened.
    var fill: Color { tone == .echo ? tint : tint.mix(with: .black, by: 0.3) }
    var banner: LinearGradient {
        LinearGradient(colors: [fill.opacity(tone == .echo ? 0.92 : 0.96), fill], startPoint: .top, endPoint: .bottom)
    }
    var ink: Color { tint }
}

/// The icon menu's five sections.
enum LabHRSection: Int, CaseIterable {
    case databases, security, management, activity, settings

    var symbol: String {
        switch self {
        case .databases: "cylinder"
        case .security: "shield"
        case .management: "square.grid.2x2"
        case .activity: "clock"
        case .settings: "gearshape"
        }
    }

    var title: String {
        switch self {
        case .databases: "Databases"
        case .security: "Security"
        case .management: "Management"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }
}

extension LabSHServer {
    /// "SQL SERVER", "POSTGRESQL": the product without its version, in capitals.
    var engineCaps: String {
        product.components(separatedBy: " ").filter { $0.first?.isNumber != true }.joined(separator: " ").uppercased()
    }
}
