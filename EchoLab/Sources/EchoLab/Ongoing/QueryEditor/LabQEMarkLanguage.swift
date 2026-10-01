import SwiftUI

// Round 28.15: one design language for everything drawn on and over the editor's text. Never
// rename a case's raw value: the owner's picks are saved under it.

enum LabQEDLCorner: String, CaseIterable {
    case mixed = "DC0 · As today: pills for errors, 3pt for the rest"
    case oneCorner = "DC1 · One corner for every mark (a setting, 3pt)"
    case round = "DC2 · Round ends for every mark"
    case square = "DC3 · Square"
}

enum LabQEDLTint: String, CaseIterable {
    case mixed = "DT0 · As today: 9% to 35%"
    case twoSteps = "DT1 · Two steps: soft 10%, strong 22%"
    case threeSteps = "DT2 · Three steps: 8%, 16%, 28%"
}

enum LabQEDLColour: String, CaseIterable {
    case mixed = "DM0 · As today"
    case meaning = "DM1 · By meaning"
    case accent = "DM2 · Accent for everything but mistakes"

    var summary: String {
        switch self {
        case .mixed: "Grey for the word at the caret, the system's yellow for find, red for mistakes, red and green for a replacement, accent for the statement."
        case .meaning: "Each colour means one thing everywhere: grey the same word, yellow found, red wrong or removed, green added or done, accent where you are (statement, selection)."
        case .accent: "The accent for the word, find and the statement; red only for mistakes and what a replacement removes."
        }
    }
}

enum LabQEDLHeight: String, CaseIterable {
    case letters = "DH0 · The letters' height (the selection keeps the line)"
    case line = "DH1 · The whole line"
}

enum LabQEDLSettings: String, CaseIterable {
    case today = "DS0 · As today: Selection Corners and Highlight Corners"
    case marks = "DS1 · One Marks section: Corners and Strength"
    case cornersOnly = "DS2 · One Corners setting for every mark"

    var summary: String {
        switch self {
        case .today: "Two corner settings; the error pill and the find indicator follow neither."
        case .marks: "Settings › Editor › Marks: Corners (Square, 2, 3, 4, 6, Round; every mark and the selection) and Strength (Subtle, Standard, Strong; scales every tint)."
        case .cornersOnly: "One corner for every mark and the selection; tints fixed."
        }
    }
}

enum LabQEDLFloating: String, CaseIterable {
    case glass = "DF0 · Glass: symbol in colour, words in grey"
    case card = "DF1 · The card's material with a shadow"

    var summary: String {
        self == .glass ? "Every pill and bubble that floats over the code (run note, error bubble, zoom, find bar) is Liquid Glass with an 11pt symbol in its colour and grey words, as the run note (R10)."
            : "Floating pills and bubbles use the card's own fill and shadow; glass stays for the toolbar."
    }
}

/// The resolved language: what each kind of mark looks like.
struct LabQEMarkLanguage {
    enum Kind: CaseIterable {
        case word, find, findCurrent, mistake, removed, added, statement
    }

    var corner: LabQEDLCorner
    var tint: LabQEDLTint
    var colour: LabQEDLColour
    var height: LabQEDLHeight
    var floating: LabQEDLFloating

    /// Echo as built (rounds 28.1 to 28.11) and 28.13's PV2 for the replacement.
    static let today = LabQEMarkLanguage(corner: .mixed, tint: .mixed, colour: .mixed, height: .letters, floating: .glass)

    func cornerRadius(for kind: Kind, height: CGFloat) -> CGFloat {
        switch corner {
        case .mixed: kind == .mistake ? height / 2 : (kind == .removed || kind == .added ? 0 : SpacingTokens.nano)
        case .oneCorner: SpacingTokens.nano
        case .round: height / 2
        case .square: 0
        }
    }

    func color(for kind: Kind) -> Color {
        let yellow = Color(nsColor: .findHighlightColor)
        switch colour {
        case .mixed, .meaning:
            switch kind {
            case .word: return ColorTokens.Text.primary
            case .find, .findCurrent: return yellow
            case .mistake, .removed: return ColorTokens.Status.error
            case .added: return ColorTokens.Status.success
            case .statement: return ColorTokens.accent
            }
        case .accent:
            switch kind {
            case .mistake, .removed: return ColorTokens.Status.error
            default: return ColorTokens.accent
            }
        }
    }

    func opacity(for kind: Kind) -> Double {
        switch tint {
        case .mixed:
            switch kind {
            case .word: 0.09
            case .find: 0.35
            case .findCurrent: 1
            case .mistake: 0.14
            case .removed: 0.2
            case .added: 0.28
            case .statement: 0.7
            }
        case .twoSteps:
            switch kind {
            case .word, .find, .added: 0.10
            case .findCurrent, .mistake, .removed: 0.22
            case .statement: 0.7
            }
        case .threeSteps:
            switch kind {
            case .word: 0.08
            case .find, .added: 0.16
            case .findCurrent, .mistake, .removed: 0.28
            case .statement: 0.7
            }
        }
    }
}
