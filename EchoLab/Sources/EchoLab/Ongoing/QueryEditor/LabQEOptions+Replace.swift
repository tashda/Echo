import Observation
import SwiftUI

// Round 28.13: search and replace together. Never rename a case's raw value: the owner's picks
// are saved under it.

/// How the replacement shows in the editor while you type it (refining 28.12's RP3).
enum LabQEReplacePreview: String, CaseIterable {
    case noPreview = "PV0 · No preview"
    case above = "PV1 · Above each match (28.12's RP3)"
    case inlineDiff = "PV2 · Inline: old struck through, new beside it"
    case inPlace = "PV3 · The new text in place, tinted"
    case currentOnly = "PV4 · Inline on the current match only"
    case withGutter = "PV5 · In place, and marked in the gutter"

    var summary: String {
        switch self {
        case .noPreview: "Matches are lit as in find; you see the change only after Replace."
        case .above: "Each match is struck through in red with the new text in a green tag above it; the tags cover the line above."
        case .inlineDiff: "Each match reads like a diff: the old word struck through in red, then the new word in green, on the same line."
        case .inPlace: "Each match already shows the new word in a soft green tint; the old word is gone from view until you close Replace."
        case .currentOnly: "Only the current match shows the inline diff; the others stay lit as matches, so the line you are on is the one you read."
        case .withGutter: "PV3, plus a small green mark beside the numbers of every line that will change, so you can see the reach of Replace All."
        }
    }
}

/// How the Replace row opens from the chevron (RP1, the owner's pick).
enum LabQEReplaceOpening: String, CaseIterable {
    case instant = "AN0 · At once"
    case grow = "AN1 · The capsule grows"
    case slide = "AN2 · The row slides down"
    case morph = "AN3 · A glass row melts out"
    case spring = "AN4 · Grows with a bounce"

    var summary: String {
        switch self {
        case .instant: "No motion: the row is there."
        case .grow: "The glass capsule grows taller with the house spring and the row fades in as it does."
        case .slide: "The row slides down from under the find row, clipped by the capsule."
        case .morph: "The Replace row is its own glass shape that melts out of the find capsule, the way macOS 26's glass controls join and part."
        case .spring: "Like AN1 with a little overshoot, and the chevron turns with it."
        }
    }

    func animation(_ motion: EchoMotion) -> Animation? {
        if motion.reduceMotion { return nil }
        switch self {
        case .instant: return nil
        case .grow, .slide, .morph: return motion.standard
        case .spring: return .spring(response: 0.42 * motion.durationScale, dampingFraction: 0.62)
        }
    }
}

/// The shortcuts that open Find and Find and Replace.
enum LabQEFindShortcuts: String, CaseIterable {
    case macOS = "SH0 · ⌘F and ⌥⌘F"
    case twice = "SH1 · ⌘F, and ⌘F again for Replace"
    case shiftCommandR = "SH2 · ⌘F and ⇧⌘R"
    case controlH = "SH3 · ⌘F and ⌃H"

    var replaceKeys: String {
        switch self {
        case .macOS: "⌥⌘F"
        case .twice: "⌘F ⌘F"
        case .shiftCommandR: "⇧⌘R"
        case .controlH: "⌃H"
        }
    }

    var summary: String {
        switch self {
        case .macOS: "Edit › Find › Find and Replace is ⌥⌘F in every Mac app (Xcode, TextEdit, Pages)."
        case .twice: "⌘F opens Find; pressing it again while Find is open opens Replace."
        case .shiftCommandR: "A letter for Replace; ⇧⌘R is free in Echo today."
        case .controlH: "VS Code's and SSMS's Ctrl+H, moved to Control on the Mac."
        }
    }
}

/// The left-hand buttons ask every playground on the page to open Find or Find and Replace.
@Observable @MainActor
final class LabQESearchCommands {
    static let shared = LabQESearchCommands()
    var openFind = 0
    var openReplace = 0
}
