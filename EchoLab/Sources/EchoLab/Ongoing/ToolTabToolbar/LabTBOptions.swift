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
        }
    }

    var hasTray: Bool { self == .tray || self == .iconTray }
    var hasIcon: Bool { self == .icon || self == .iconTray }
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
    var tie: LabTBTie = .iconTray
    var groups: LabTBGroups = .dividers
    var run: LabTBRun = .plain
    var move: LabTBMove = .buttons
    var mainLook: LabTBMainLook = .word
    var gap: LabTBGap = .fixed
    var motion: LabTBMotion = .morph
    var running = false

    static let today = LabTBLook(tie: .none, groups: .separate, run: .capsule, move: .main, mainLook: .word, gap: .fixed, motion: .melt)

    @MainActor static func from(_ v: RoundValues) -> LabTBLook {
        LabTBLook(tie: .init(rawValue: v["tie"]) ?? .iconTray, groups: .init(rawValue: v["groups"]) ?? .dividers,
                  run: .init(rawValue: v["run"]) ?? .plain, move: .init(rawValue: v["move"]) ?? .buttons,
                  mainLook: .init(rawValue: v["mainLook"]) ?? .word, gap: .init(rawValue: v["gap"]) ?? .fixed,
                  motion: .init(rawValue: v["motion"]) ?? .morph,
                  running: (LabTBState(rawValue: v["state"]) ?? .resting) == .running)
    }
}
