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

struct LabHRLook {
    var form: LabHRForm
    var dock: LabHRDock
    var right: LabHRRight
    var reach: LabHRReach
    var eyebrow: LabHREyebrow
    var tone: LabHRTone

    static let today = LabHRLook(form: .wash, dock: .glass, right: .none, reach: .dock, eyebrow: .version, tone: .echo)

    @MainActor init(_ values: RoundValues) {
        form = LabHRForm(rawValue: values["form"]) ?? .slim
        dock = LabHRDock(rawValue: values["dock"]) ?? .pill
        right = LabHRRight(rawValue: values["right"]) ?? .section
        reach = LabHRReach(rawValue: values["reach"]) ?? .dock
        eyebrow = LabHREyebrow(rawValue: values["eyebrow"]) ?? .engine
        tone = LabHRTone(rawValue: values["tone"]) ?? .echo
    }

    init(form: LabHRForm, dock: LabHRDock, right: LabHRRight, reach: LabHRReach, eyebrow: LabHREyebrow, tone: LabHRTone) {
        self.form = form
        self.dock = dock
        self.right = right
        self.reach = reach
        self.eyebrow = eyebrow
        self.tone = tone
    }

    func with(form: LabHRForm? = nil, dock: LabHRDock? = nil) -> LabHRLook {
        var copy = self
        if let form { copy.form = form }
        if let dock { copy.dock = dock }
        return copy
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
