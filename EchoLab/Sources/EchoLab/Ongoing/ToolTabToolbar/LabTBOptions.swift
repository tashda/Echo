import SwiftUI

/// Round 37.5: how a tab's own buttons show they belong to the tab in front.
enum LabTBTie: String, CaseIterable {
    case none = "TT0 · Nothing ties them: plain glass groups (today's query toolbar)"
    case tint = "TT1 · The tab's groups take a faint tint of the tab's colour"
    case icon = "TT2 · The groups start with the tab's own symbol, as in its tab"
    case tray = "TT3 · One tray holds the tab's groups, in the tab bar's grey"
    case plate = "TT4 · The groups sit on a white raised plate, like the active tab"
    case name = "TT5 · The tab's name leads the groups, in small grey text"
    case dot = "TT6 · A dot of the tab's colour before the groups"
    case iconTray = "TT7 · TT3 and TT2: a grey tray that starts with the tab's symbol"
    // Revision 2: the tab's symbol shown without any glass around it.
    case bare = "TT8 · The symbol on its own before the buttons, no shape around it"
    case bareTint = "TT9 · TT8 in the tab's colour"
    case tucked = "TT10 · A small symbol tucked against the buttons' left end"
    case hairline = "TT11 · The symbol, a short hairline, then the buttons"
    case chevron = "TT12 · The symbol and a small › pointing into the buttons"
    case outline = "TT13 · The symbol in a thin outlined circle, no glass, no fill"
    case engraved = "TT14 · The symbol pressed into the toolbar, with an inner shadow"
    case watermark = "TT15 · A large, faint symbol behind the buttons' left end"
    case badge = "TT16 · A tiny badge with the symbol on the buttons' top-left corner"
    case caption = "TT17 · A tiny symbol under the buttons, where toolbar labels go"
    case after = "TT18 · The symbol after the buttons, before the window's icons"
    case tintBoth = "TT19 · The symbol in the tab's colour, and the glass faintly tinted with it"
    case underline = "TT20 · The symbol, and a short line of the tab's colour under the buttons"
    case flash = "TT21 · The symbol shows for a moment when you switch tabs, then fades"
    case hover = "TT22 · A dot at rest; the symbol and the tab's name when you point at the buttons"

    static let revision2: [LabTBTie] = [.bare, .bareTint, .tucked, .hairline, .chevron, .outline, .engraved, .watermark,
                                        .badge, .caption, .after, .tintBoth, .underline, .flash, .hover]

    var summary: String {
        switch self {
        case .none: "What the query tab does today: nothing says the groups change with the tab."
        case .tint: "The glass itself carries the tab's colour (accent for a query, the tool's tint for a tool); quiet, but colour alone is easy to miss."
        case .icon: "The same symbol as the tab in the strip, greyed, leads the groups: a label you already know, no new shape."
        case .tray: "The tab bar's grey plate reappears in the toolbar around the tab's groups, so they read as part of the tabs, not the window."
        case .plate: "The active tab is a white raised plate; the same plate under its buttons is the most literal link, and the loudest."
        case .name: "Says it in words (\"Query 2\"); clear, but costs 60 to 120pt of toolbar and repeats the tab."
        case .dot: "The smallest mark; works only if tabs have colours you know."
        case .iconTray: "The tray says 'from the tabs', the symbol says 'this one'; the clearest, at the cost of one more shape."
        case .bare: "TT2 without the glass: the same symbol as the tab, standing on the toolbar like a label; nothing to press."
        case .bareTint: "The tab's colour makes it a little louder and ties it to the tab's tile in the header."
        case .tucked: "Smaller and closer, so it reads as the group's own label rather than another item."
        case .hairline: "A divider between label and buttons, like a breadcrumb: Query 2 | ▶ ✦ ⚠."
        case .chevron: "Says 'these belong to': the › points from the tab's symbol into its buttons."
        case .outline: "Marks the symbol as not-a-button with a different shape: a thin ring instead of glass."
        case .engraved: "Pressed into the toolbar instead of standing on it: visibly inert."
        case .watermark: "Felt more than read: a big faint symbol the buttons sit on."
        case .badge: "Like an app's badge: small, but pinned to the group so it moves with it."
        case .caption: "Where macOS draws toolbar labels: under the buttons, tiny and grey."
        case .after: "On the other side: the buttons, then whose they are, then the window's own."
        case .tintBoth: "Colour carries the tie twice: the symbol and a faint tint in the glass."
        case .underline: "A coloured underline under the buttons, like the active tab's marker, with the symbol before them."
        case .flash: "Only while you switch: the symbol appears, then fades, so at rest the toolbar is as quiet as today."
        case .hover: "At rest a dot of the tab's colour; pointing at the buttons shows whose they are."
        }
    }

    var hasTray: Bool { self == .tray || self == .iconTray }
    var hasIcon: Bool { self == .icon || self == .iconTray }
}

/// Revision 2: the colour of the tab's symbol where the tie draws it plainly.
enum LabTBSymbolColour: String, CaseIterable {
    case secondary = "SC0 · Grey, like a label"
    case tertiary = "SC1 · Lighter grey"
    case tint = "SC2 · The tab's colour"
    case primary = "SC3 · Black, like the buttons"

    func color(_ tab: LabTBTab) -> Color {
        switch self {
        case .secondary: ColorTokens.Text.secondary
        case .tertiary: ColorTokens.Text.tertiary
        case .tint: tab.tint
        case .primary: ColorTokens.Text.primary
        }
    }
}

/// Revision 2: the size of the tab's symbol.
enum LabTBSymbolSize: String, CaseIterable {
    case small = "SZ0 · 11pt, smaller than the buttons"
    case same = "SZ1 · 13pt, the buttons' size"
    case large = "SZ2 · 14pt, a little larger"

    var font: Font {
        switch self {
        case .small: TypographyTokens.detail
        case .same: TypographyTokens.standard
        case .large: TypographyTokens.prominent
        }
    }
}

/// How a tab with several groups of buttons shows them.
enum LabTBGroups: String, CaseIterable {
    case separate = "GR0 · Each group its own glass capsule (today)"
    case dividers = "GR1 · One capsule, the groups split by short hairlines"
    case union = "GR2 · The groups melt into one glass shape"
    case overflow = "GR3 · The first group shows; the others in a ⋯ menu"
}

/// How Run sits among the query tab's buttons.
enum LabTBRun: String, CaseIterable {
    case capsule = "RN0 · Run keeps its own capsule that turns red (round 24)"
    case plain = "RN1 · Run is a plain button in the tab's group; only its symbol turns red"
    case lead = "RN2 · Run leads the tab's group in a small capsule of its own"
}

/// What moves from a tool's header line into the toolbar.
enum LabTBMove: String, CaseIterable {
    case everything = "MV0 · Every control; the header keeps only the name"
    case buttons = "MV1 · The buttons; pickers and search stay on the header line"
    case main = "MV2 · Only the main action"
}

/// How a tool's main action looks in the toolbar.
enum LabTBMainLook: String, CaseIterable {
    case symbol = "MA0 · A symbol, like every toolbar button; the tooltip names it"
    case word = "MA1 · Symbol and word (37.3's PA1), the only word in the toolbar"
}

/// What separates the tab's groups from the window's.
enum LabTBGap: String, CaseIterable {
    case fixed = "GP0 · The toolbar's own fixed gap (today)"
    case wide = "GP1 · A wider gap"
    case hairline = "GP2 · A short hairline"

    var width: CGFloat {
        switch self {
        case .fixed: SpacingTokens.xxs2
        case .wide: SpacingTokens.lg
        case .hairline: SpacingTokens.sm
        }
    }
}

/// What the tab's groups do when you switch tabs.
enum LabTBMotion: String, CaseIterable {
    case melt = "SW0 · The system's melt (today)"
    case fade = "SW1 · A cross-fade"
    case morph = "SW2 · The glass reshapes from one tab's groups into the next"
    case slide = "SW3 · Out to the right, the new ones in from the left"
}

/// Playground: a query or trace running.
enum LabTBState: String, CaseIterable {
    case resting = "Resting"
    case running = "Running"
}

/// Everything a drawing of the toolbar reads from the controls.
struct LabTBLook {
    var tie: LabTBTie = .bare
    var groups: LabTBGroups = .dividers
    var run: LabTBRun = .plain
    var move: LabTBMove = .buttons
    var mainLook: LabTBMainLook = .word
    var gap: LabTBGap = .fixed
    var motion: LabTBMotion = .morph
    var running = false
    var symbolColour: LabTBSymbolColour = .secondary
    var symbolSize: LabTBSymbolSize = .same

    static let today = LabTBLook(tie: .none, groups: .separate, run: .capsule, move: .main, mainLook: .word, gap: .fixed, motion: .melt)

    @MainActor static func from(_ v: RoundValues) -> LabTBLook {
        LabTBLook(tie: .init(rawValue: v["tie"]) ?? .bare, groups: .init(rawValue: v["groups"]) ?? .dividers,
                  run: .init(rawValue: v["run"]) ?? .plain, move: .init(rawValue: v["move"]) ?? .buttons,
                  mainLook: .init(rawValue: v["mainLook"]) ?? .word, gap: .init(rawValue: v["gap"]) ?? .fixed,
                  motion: .init(rawValue: v["motion"]) ?? .morph,
                  running: (LabTBState(rawValue: v["state"]) ?? .resting) == .running,
                  symbolColour: .init(rawValue: v["symbolColour"]) ?? .secondary,
                  symbolSize: .init(rawValue: v["symbolSize"]) ?? .same)
    }
}
