import SwiftUI
import AppKit

/// Round 53. The header the owner chose in round 50 (F5: a banner with an eyebrow over a large name,
/// a hairline edge, the icon menu without a capsule, the selected icon filled) is the baseline.
/// This round offers what a user could change about it, in steps, and nine ways the collapse
/// chevron could look and move.
enum LabHCFamily: String, CaseIterable {
    case system = "TY0 · System"
    case rounded = "TY1 · Rounded"
    case serif = "TY2 · Serif (New York)"
    case mono = "TY3 · Monospaced"
    case expanded = "TY4 · Expanded"

    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCSize: String, CaseIterable {
    case small = "SZ0 · Small (18)"
    case medium = "SZ1 · Medium (22)"
    case large = "SZ2 · Large (26)"

    var points: CGFloat {
        switch self {
        case .small: 18
        case .medium: 22
        case .large: 26
        }
    }
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCWeight: String, CaseIterable {
    case regular = "WT0 · Regular"
    case medium = "WT1 · Medium"
    case semibold = "WT2 · Semibold"
    case bold = "WT3 · Bold"
    case heavy = "WT4 · Heavy"

    var weight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCAlign: String, CaseIterable {
    case leading = "AL0 · Leading"
    case centred = "AL1 · Centred"
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCDensity: String, CaseIterable {
    case compact = "DN0 · Compact"
    case standard = "DN1 · Standard"
    case roomy = "DN2 · Roomy"

    var vertical: CGFloat {
        switch self {
        case .compact: SpacingTokens.xs
        case .standard: SpacingTokens.sm
        case .roomy: SpacingTokens.md1
        }
    }
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCEyebrow: String, CaseIterable {
    case section = "EB0 · The section: DATABASES"
    case engine = "EB1 · The engine: SQL SERVER"
    case engineSection = "EB2 · The engine and the section"
    case none = "EB3 · None"
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCFill: String, CaseIterable {
    case gradient = "FL0 · Gradient (Echo's banner)"
    case flat = "FL1 · Flat"
    case frosted = "FL2 · Frosted: the colour over a material"
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCText: String, CaseIterable {
    case white = "TC0 · Always white"
    case automatic = "TC1 · Automatic: dark on light colours"
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCEdge: String, CaseIterable {
    case sharp = "ED0 · Sharp"
    case hairline = "ED1 · Sharp with a hairline of light"
    case soft = "ED2 · A soft fade"
    case frosted = "ED3 · A frosted fade"
    case rounded = "ED4 · Rounded bottom corners"
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

enum LabHCIconSize: String, CaseIterable {
    case small = "IS0 · Small (13)"
    case medium = "IS1 · Medium (15)"
    case large = "IS2 · Large (17)"

    var points: CGFloat {
        switch self {
        case .small: 13
        case .medium: 15
        case .large: 17
        }
    }
    var short: String { rawValue.components(separatedBy: " · ").last ?? rawValue }
}

/// How much of this the user gets to change.
enum LabHCLevel: String, CaseIterable {
    case none = "LV0 · Nothing: the colour and the icon are all"
    case simple = "LV1 · Simple: the typeface and the size of the name"
    case standard = "LV2 · Standard: also the eyebrow, the edge and automatic text colour"
    case full = "LV3 · Full: also weight, alignment, spacing, fill and icon size"

    enum Row { case family, size, eyebrow, edge, textColour, weight, alignment, density, fill, iconSize }

    func offers(_ row: Row) -> Bool {
        switch row {
        case .family, .size: self != .none
        case .eyebrow, .edge, .textColour: self == .standard || self == .full
        case .weight, .alignment, .density, .fill, .iconSize: self == .full
        }
    }

    var summary: String {
        switch self {
        case .none: "Today: a server has a colour (and, since round 51, a symbol); the header's type is Echo's."
        case .simple: "Two rows in Settings › Appearance › Server Header: Typeface and Size. Every change is visible in the card."
        case .standard: "Adds the eyebrow (the section, the engine, both, none), how the banner ends, and automatic contrast so yellow and amber banners get dark type."
        case .full: "Adds weight, alignment, spacing, the banner's fill and the icon size: ten rows, enough to make the card unlike anyone else's."
        }
    }
}

enum LabHCChevron: String, CaseIterable {
    case today = "CH0 · A chevron on hover, no motion (Echo today)"
    case turn = "CH1 · A chevron that turns a quarter, on a spring"
    case disc = "CH2 · A chevron in a soft disc that swells on hover and turns"
    case flip = "CH3 · A chevron that flattens to a line and flips"
    case label = "CH4 · A small pill that says Collapse or Expand"
    case handle = "CH5 · A handle on the banner's bottom edge"
    case symbol = "CH6 · A compress and expand symbol that swaps"
    case nudge = "CH7 · A chevron that nudges to invite a click"
    case count = "CH8 · The database count when collapsed, a chevron when open"

    var summary: String {
        switch self {
        case .today: "Round 30.2's chevron: appears on hover while open, always while collapsed, and does not move."
        case .turn: "The same chevron, rotating 90° as the card folds, with the motion you choose below."
        case .disc: "A 22pt disc of white at 20% holds the chevron, which turns; the disc swells 12% under the pointer."
        case .flip: "Drawn as a path: an up-pointing chevron flattens to a line and comes out pointing down as the card closes. Nothing else in the app does this."
        case .label: "A 22pt capsule with the word and a chevron; on hover only, so the header stays clean."
        case .handle: "No chevron: a 28pt bar at the banner's bottom edge that widens under the pointer and squashes when you click, like a sheet's grabber."
        case .symbol: "Two symbols (compress, expand) that swap with a symbol effect. Says what it does rather than which way it points."
        case .nudge: "The chevron drifts down 2pt and back while the pointer is on the header, asking to be clicked."
        case .count: "Collapsed, the header shows how many databases are inside, in a capsule, then the chevron; open, the plain chevron."
        }
    }
}

enum LabHCChevronShows: String, CaseIterable {
    case hover = "CV0 · On hover while open, always while collapsed (today)"
    case always = "CV1 · Always"
    case collapsed = "CV2 · Only while collapsed"
    case hoverOnly = "CV3 · Only on hover"
}

enum LabHCMotion: String, CaseIterable {
    case bounce = "MO0 · The house spring, a little bounce"
    case smooth = "MO1 · Smooth, no overshoot"
    case snappy = "MO2 · Snappy"
    case none = "MO3 · None"

    var animation: Animation? {
        switch self {
        case .bounce: .bouncy(duration: 0.45, extraBounce: 0.08)
        case .smooth: .smooth(duration: 0.35)
        case .snappy: .snappy(duration: 0.25)
        case .none: nil
        }
    }
}

struct LabHCLook {
    var family = LabHCFamily.system
    var size = LabHCSize.medium
    var weight = LabHCWeight.semibold
    var align = LabHCAlign.leading
    var density = LabHCDensity.standard
    var eyebrow = LabHCEyebrow.section
    var fill = LabHCFill.gradient
    var text = LabHCText.white
    var edge = LabHCEdge.hairline
    var iconSize = LabHCIconSize.medium
    var chevron = LabHCChevron.turn
    var shows = LabHCChevronShows.hover
    var motion = LabHCMotion.bounce
    var colour = LabHRColour.sample
    var level = LabHCLevel.full

    @MainActor init(_ values: RoundValues) {
        family = LabHCFamily(rawValue: values["family"]) ?? .system
        size = LabHCSize(rawValue: values["size"]) ?? .medium
        weight = LabHCWeight(rawValue: values["weight"]) ?? .semibold
        align = LabHCAlign(rawValue: values["align"]) ?? .leading
        density = LabHCDensity(rawValue: values["density"]) ?? .standard
        eyebrow = LabHCEyebrow(rawValue: values["eyebrow"]) ?? .section
        fill = LabHCFill(rawValue: values["fill"]) ?? .gradient
        text = LabHCText(rawValue: values["text"]) ?? .white
        edge = LabHCEdge(rawValue: values["edge"]) ?? .hairline
        iconSize = LabHCIconSize(rawValue: values["iconSize"]) ?? .medium
        chevron = LabHCChevron(rawValue: values["chevron"]) ?? .turn
        shows = LabHCChevronShows(rawValue: values["shows"]) ?? .hover
        motion = LabHCMotion(rawValue: values["motion"]) ?? .bounce
        colour = LabHRColour(rawValue: values["colour"]) ?? .sample
        level = LabHCLevel(rawValue: values["level"]) ?? .full
    }

    init() {}

    func with(chevron: LabHCChevron) -> LabHCLook {
        var copy = self
        copy.chevron = chevron
        return copy
    }

    /// The level hides what the user cannot change: those rows stay at Echo's choice.
    var applied: LabHCLook {
        var copy = LabHCLook()
        copy.chevron = chevron; copy.shows = shows; copy.motion = motion; copy.colour = colour; copy.level = level
        if level.offers(.family) { copy.family = family }
        if level.offers(.size) { copy.size = size }
        if level.offers(.eyebrow) { copy.eyebrow = eyebrow }
        if level.offers(.edge) { copy.edge = edge }
        if level.offers(.textColour) { copy.text = text }
        if level.offers(.weight) { copy.weight = weight }
        if level.offers(.alignment) { copy.align = align }
        if level.offers(.density) { copy.density = density }
        if level.offers(.fill) { copy.fill = fill }
        if level.offers(.iconSize) { copy.iconSize = iconSize }
        return copy
    }

    var nameFont: Font {
        let base = Font.system(size: size.points, weight: weight.weight, design: family == .system || family == .expanded ? .default
            : (family == .rounded ? .rounded : (family == .serif ? .serif : .monospaced)))
        return family == .expanded ? base.width(.expanded) : base
    }

    func tint(for server: LabSHServer, scheme: ColorScheme) -> Color { colour.color(scheme) ?? server.color }

    /// White type, or dark type on a light colour.
    func textColor(on tint: Color) -> Color {
        guard text == .automatic, let rgb = NSColor(tint).usingColorSpace(.sRGB) else { return ColorTokens.Text.onFill }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luminance > 0.62 ? Color.black.opacity(0.82) : ColorTokens.Text.onFill
    }
}
