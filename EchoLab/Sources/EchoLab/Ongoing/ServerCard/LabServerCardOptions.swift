import SwiftUI

// Round 16 · Server card: every choice the playground compares. "Today" options reproduce what
// Echo does now, so each fix can be judged against the bug it replaces.

/// How the server's name and its section icons are drawn at the top of the card.
enum LabSCHeader: String, CaseIterable, Identifiable {
    case today = "H0 · Today"
    case navigator = "H1 · Navigator bar"
    case segmented = "H2 · Segmented"
    case oneLine = "H3 · One line"
    case sectionMenu = "H4 · Section menu"
    case glass = "H5 · Glass capsule"
    case labelled = "H6 · Labelled current"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .today: "Echo now: bold name, full build on the right, equal tiles 30pt tall whatever the density."
        case .navigator: "Xcode's navigator bar: small icons spread across, the current one in the accent colour, no fill, a hairline under it."
        case .segmented: "The system segmented control with symbols. Fully native, but mono only and one menu for the whole control."
        case .oneLine: "Name and icons share one line. Saves a row; the version moves to the tooltip."
        case .sectionMenu: "The current section's icon and name as a pull-down. Scales to any number of sections."
        case .glass: "Icons in a Liquid Glass capsule, as a control floating over the tree. Glass on a control, not on the card."
        case .labelled: "Today's tiles, but the current one also shows its name, so icons never have to be guessed."
        }
    }
}

/// What happens to rows as they scroll under the pinned header.
enum LabSCEdge: String, CaseIterable, Identifiable {
    case material = "Today (material)"
    case blurRows = "Blur rows"
    case fadeRows = "Fade rows"
    case hairline = "Hairline"
    case system = "System edge"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .material: "Echo now: a thin material over the rows. It tints them grey and only its last 12pt fade."
        case .blurRows: "Each row blurs and fades as it slides under the header. No tint, no edge, works with stacked cards."
        case .fadeRows: "Rows only fade as they reach the header. The quietest option."
        case .hairline: "No effect; a hairline appears under the header while rows are under it."
        case .system: "macOS 26's own soft scroll edge, as approved in round 14. Only possible when one server's card fills the column."
        }
    }
}

/// How the card changes when another section is chosen.
enum LabSCSwitch: String, CaseIterable, Identifiable {
    case today = "Today (rows drop in)"
    case crossfade = "Crossfade"
    case slide = "Slide"
    case instant = "Instant"
    var id: String { rawValue }
}

/// What the card shows while a section or folder loads.
enum LabSCLoading: String, CaseIterable, Identifiable {
    case shimmer = "Today (shimmer)"
    case skeleton = "Quiet skeleton"
    case keep = "Keep + spinner"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .shimmer: "Echo now: three shimmering bars at the child indent."
        case .skeleton: "Rows shaped like real rows (icon and label), shown only if loading takes longer than a quarter second."
        case .keep: "Nothing moves until the items are there: a spinner sits in the icon or count slot, then the rows arrive once."
        }
    }
}

enum LabSCLatency: String, CaseIterable, Identifiable {
    case fast = "Fast server"
    case slow = "Slow server"
    var id: String { rawValue }
    var duration: Duration { self == .fast ? .milliseconds(150) : .milliseconds(1_200) }
}

enum LabSCIconStyle: String, CaseIterable, Identifiable {
    case mono = "Mono"
    case duotone = "Duotone"
    var id: String { rawValue }
}

enum LabSCCounts: String, CaseIterable, Identifiable {
    case hover = "On hover"
    case always = "Always"
    case hidden = "Hidden"
    var id: String { rawValue }
}

enum LabSCSelection: String, CaseIterable, Identifiable {
    case today = "Today (pulled left)"
    case symmetric = "Symmetric"
    var id: String { rawValue }
}

enum LabSCVersion: String, CaseIterable, Identifiable {
    case below = "Under the name"
    case beside = "Beside the name"
    case tooltip = "Tooltip only"
    var id: String { rawValue }
}

/// Settings › Appearance › Sidebar size. Row slots match Echo's `baseRowHeight(for:)`.
enum LabSCDensity: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case small = "Small"
    case medium = "Default"
    case large = "Large"
    var id: String { rawValue }

    var rowSlot: CGFloat {
        switch self {
        case .compact: SpacingTokens.md2 + SpacingTokens.micro
        case .small: SpacingTokens.lg + SpacingTokens.micro
        case .medium: SpacingTokens.lg + SpacingTokens.xxs1
        case .large: SpacingTokens.xl + SpacingTokens.nano
        }
    }

    var labelFont: Font {
        switch self {
        case .compact: TypographyTokens.label
        case .small: TypographyTokens.detail
        case .medium: TypographyTokens.standard
        case .large: TypographyTokens.prominent
        }
    }

    var iconFont: Font { labelFont.weight(.light) }

    var nameFont: Font {
        switch self {
        case .compact: TypographyTokens.detail.weight(.bold)
        case .small: TypographyTokens.caption2.weight(.bold)
        case .medium: TypographyTokens.standard.weight(.bold)
        case .large: TypographyTokens.prominent.weight(.bold)
        }
    }

    /// The dock follows the size setting too (bug: Echo's dock is fixed at 14pt icons, 30pt tall).
    var dockIconFont: Font {
        switch self {
        case .compact: TypographyTokens.detail
        case .small: TypographyTokens.caption2
        case .medium: TypographyTokens.prominent
        case .large: TypographyTokens.displayMedium.weight(.regular)
        }
    }

    var dockHeight: CGFloat {
        switch self {
        case .compact: SpacingTokens.md2 + SpacingTokens.xxxs
        case .small: SpacingTokens.lg
        case .medium: SpacingTokens.lg + SpacingTokens.xxs
        case .large: SpacingTokens.xl
        }
    }
}

/// Every choice in one value, passed down the card's views.
struct LabSCOptions {
    var header: LabSCHeader = .navigator
    var edge: LabSCEdge = .blurRows
    var switchMotion: LabSCSwitch = .crossfade
    var loading: LabSCLoading = .skeleton
    var latency: LabSCLatency = .slow
    var dockIcons: LabSCIconStyle = .mono
    var treeIcons: LabSCIconStyle = .duotone
    var density: LabSCDensity = .medium
    var counts: LabSCCounts = .hover
    var selection: LabSCSelection = .symmetric
    var version: LabSCVersion = .below
    var speed: LabSpeed = .standard

    /// The system edge needs the scroll view's own top bar, so the column shows one server.
    var showsOneServer: Bool { edge == .system }
}
