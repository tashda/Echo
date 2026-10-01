import SwiftUI

// Round 19 · Section dock: every choice its three pages compare. The first case of each is what
// Echo does today (commit f054cc97), so every proposal is judged against the real thing.

// MARK: - Switching (page 1)

/// How the card changes when another section is chosen.
enum LabSDSwitch: String, CaseIterable, Identifiable {
    case today = "S0 · Today"
    case cardCrossfade = "S1 · Card crossfade"
    case swapAndSettle = "S2 · Swap, height settles"
    case fadeThrough = "S3 · Fade through"
    case slide = "S4 · Slide sideways"
    case instant = "S5 · Instant"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .today: "Echo now: every row fades on its own while the list animates each row into place, and the view glides to where the section was left."
        case .cardCrossfade: "The card's rows change as one piece: the old set fades out while the new fades in on top, and only the card's bottom edge moves."
        case .swapAndSettle: "The new rows are there at once, with no fade; only the card's bottom edge settles to its new height."
        case .fadeThrough: "The old rows fade out quickly, the new rows fade in, and the bottom edge settles between them. Nothing moves sideways or up."
        case .slide: "The rows slide left or right, in the order of the icons."
        case .instant: "No animation at all."
        }
    }
}

/// Where the view scrolls when a section is chosen.
enum LabSDSwitchScroll: String, CaseIterable, Identifiable {
    case today = "Glide to where it was (today)"
    case stay = "Stay put"
    case jump = "Jump to where it was"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .today: "Echo now: an animated scroll to where that section was left, or to the server's name."
        case .stay: "The view doesn't scroll. If the new section is shorter, the card simply ends higher."
        case .jump: "Returns to where that section was left, instantly, before the rows appear."
        }
    }
}

/// What the other cards do when one card changes height.
enum LabSDNeighbours: String, CaseIterable, Identifiable {
    case today = "N0 · Today"
    case onlyChanged = "N1 · Only the changed card"
    case holdPosition = "N2 · Only the changed card, view holds"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .today: "Echo now: every card animates on any change, and when the list gets shorter the view scrolls back, moving the cards above."
        case .onlyChanged: "Only the card that changed animates; cards below follow its edge. The view may still scroll back when the list gets shorter."
        case .holdPosition: "As N1, and the view never scrolls back by itself: the room below the last card stays until you scroll up."
        }
    }
}

// MARK: - Capsule (page 2)

enum LabSDCapsuleStyle: String, CaseIterable, Identifiable {
    case clearGlass = "C0 · Clear glass (today)"
    case tintedGlass = "C1 · Tinted glass"
    case frostedGlass = "C2 · Frosted glass"
    case filledTrack = "C3 · Filled track"
    case raisedPill = "C4 · Track with raised pill"
    case edgedGlass = "C5 · Glass with an edge"
    case glassPill = "C6 · Glass, current on a pill"
    case bar = "C7 · Bar, no capsule"
    case floating = "C8 · Floating glass"
    case underline = "C9 · Underline"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .clearGlass: "Echo now: regular Liquid Glass. Over the white card there is little for it to show."
        case .tintedGlass: "The glass takes a faint wash of the accent colour."
        case .frostedGlass: "The glass over a light grey fill, so it reads as a control even with nothing under it."
        case .filledTrack: "No glass: a quiet grey capsule, like the tree's hover fill."
        case .raisedPill: "The system segmented control's look: a grey track with the current icon on a raised white pill."
        case .edgedGlass: "Glass with a hairline edge and a soft shadow, so its outline is always visible."
        case .glassPill: "Glass capsule; the current icon sits on its own grey pill inside it."
        case .bar: "Xcode's navigator bar: no capsule, icons spread across, a hairline under them."
        case .floating: "A narrower glass capsule that hugs the icons and floats with a shadow."
        case .underline: "No capsule; a short accent bar under the current icon."
        }
    }
}

enum LabSDIconWeight: String, CaseIterable, Identifiable {
    case light = "Light"
    case regular = "Regular (today)"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    var id: String { rawValue }

    var weight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

enum LabSDIconSize: String, CaseIterable, Identifiable {
    case today = "Today"
    case larger = "One step larger"
    case largest = "Two steps larger"
    var id: String { rawValue }
    var steps: Int { self == .today ? 0 : self == .larger ? 1 : 2 }
}

/// How the current section's icon stands out.
enum LabSDCurrentMark: String, CaseIterable, Identifiable {
    case accent = "Accent colour (today)"
    case filled = "Accent, filled symbol"
    case dot = "Accent with a dot"
    case pill = "Accent on a pill"
    var id: String { rawValue }
}

/// Where the current section's name shows, so icons never have to be guessed.
enum LabSDSectionName: String, CaseIterable, Identifiable {
    case none = "Nowhere (today)"
    case inCapsule = "Beside its icon"
    case underName = "Under the server's name"
    case aboveRows = "Above the rows"
    var id: String { rawValue }
}

enum LabSDHover: String, CaseIterable, Identifiable {
    case none = "None (today)"
    case fill = "Grey circle"
    case lift = "Icon grows"
    var id: String { rawValue }
}

// MARK: - Sections (page 3)

/// How SQL Server's eight server-level folders become dock sections.
enum LabSDGrouping: String, CaseIterable, Identifiable {
    case today = "G0 · Today (eight)"
    case ssms = "G1 · SSMS five"
    case serverObjects = "G2 · Server Objects holds the rest"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .today: "Echo now: Databases, Security, Database Snapshots, Agent Jobs, Management, Integration Services, Linked Servers, Server Triggers."
        case .ssms: "As SSMS groups them: Database Snapshots at the end of Databases, Linked Servers and Server Triggers in Server Objects, Integration Services in Management."
        case .serverObjects: "Databases, Security, Agent, Management, and Server Objects holding Snapshots, Integration Services, Linked Servers and Server Triggers."
        }
    }
}

enum LabSDLimit: String, CaseIterable, Identifiable {
    case four = "4"
    case five = "5"
    case six = "6"
    case none = "No limit"
    var id: String { rawValue }
    var count: Int? { Int(rawValue) }
}

/// What happens to sections that don't fit.
enum LabSDOverflow: String, CaseIterable, Identifiable {
    case menu = "M0 · » menu (today)"
    case menuWithActions = "M1 · » menu with submenus"
    case moreSection = "M2 · More as a section"
    case scroll = "M3 · Capsule scrolls"
    case shrink = "M4 · Icons shrink to fit"
    case secondRow = "M5 · Second row"
    var id: String { rawValue }

    var summary: String {
        switch self {
        case .menu: "Echo now: a pull-down; its items can't be right-clicked."
        case .menuWithActions: "Each item in » opens a submenu: Show, then that section's own actions, so nothing needs a right-click."
        case .moreSection: "» is a section like the others: the card lists the left-out sections as folders, which open and right-click as usual."
        case .scroll: "Every section gets an icon; the capsule scrolls sideways, faded at its ends."
        case .shrink: "Every section gets an icon; the icons get smaller to fit."
        case .secondRow: "Every section gets an icon; the ones that don't fit go on a second row."
        }
    }
}

/// Everything the tree draws, one value for all three pages.
struct LabSDOptions {
    var switchMotion: LabSDSwitch = .today
    var switchScroll: LabSDSwitchScroll = .today
    var neighbours: LabSDNeighbours = .today
    var capsule: LabSDCapsuleStyle = .clearGlass
    var weight: LabSDIconWeight = .regular
    var size: LabSDIconSize = .today
    var currentMark: LabSDCurrentMark = .accent
    var sectionName: LabSDSectionName = .none
    var hover: LabSDHover = .none
    var grouping: LabSDGrouping = .today
    var limit: LabSDLimit = .four
    var overflow: LabSDOverflow = .menu
    var density: LabSDDensity = .medium
    /// Echo today: SQL Server's blueprint docks four sections; other types dock all of theirs.
    var usesBlueprintDock = false

    /// What Echo does today (commit f054cc97).
    static let today: LabSDOptions = {
        var options = LabSDOptions()
        options.usesBlueprintDock = true
        return options
    }()
}

/// The sidebar size setting, as Echo has it.
enum LabSDDensity: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case small = "Small"
    case medium = "Default"
    case large = "Large"
    var id: String { rawValue }

    /// Row slot heights, Echo's `ObjectBrowserOutlineView.baseRowHeight(for:)`.
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

    var nameFont: Font {
        switch self {
        case .compact: TypographyTokens.detail.weight(.bold)
        case .small: TypographyTokens.caption2.weight(.bold)
        case .medium: TypographyTokens.standard.weight(.bold)
        case .large: TypographyTokens.prominent.weight(.bold)
        }
    }

    /// Echo's `LayoutTokens.ExplorerDock.capsuleHeight(for:)`.
    var capsuleHeight: CGFloat {
        switch self {
        case .compact: SpacingTokens.md2 + SpacingTokens.xxxs
        case .small: SpacingTokens.lg
        case .medium: SpacingTokens.lg + SpacingTokens.xxs
        case .large: SpacingTokens.xl
        }
    }

    /// Echo's `ExplorerDockRow.iconFont` for this size, then larger steps.
    func dockIconFont(steps: Int) -> Font {
        let fonts: [Font] = [TypographyTokens.detail, TypographyTokens.caption2, TypographyTokens.prominent,
                             TypographyTokens.displayMedium, TypographyTokens.title2, TypographyTokens.title]
        let start = switch self {
        case .compact: 0
        case .small: 1
        case .medium: 2
        case .large: 3
        }
        return fonts[max(0, min(start + steps, fonts.count - 1))]
    }
}
