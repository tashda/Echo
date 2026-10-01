import SwiftUI

// Round 28: the choices for the statement at the caret, marks in the text, errors and the run
// note. Never rename a case's raw value: the owner's picks are saved under it.

enum LabQEStatementLook: String, CaseIterable {
    case band = "B0 · Accent band (today)"
    case bracket = "B1 · A bracket in the gutter"
    case nothing = "B2 · Nothing"
    case hoverBand = "B3 · Band while hovering the Run arrow"

    var summary: String {
        switch self {
        case .band: "Accent at 6% behind every line of the statement, from the gutter to the edge."
        case .bracket: "A 2pt accent bar beside the statement's line numbers; the text stays untinted."
        case .nothing: "Only the Run arrow says which statement ⌘↩ at Cursor would run."
        case .hoverBand: "Nothing while typing; the band shows what the arrow will run when you point at it."
        }
    }
}

enum LabQERunArrow: String, CaseIterable {
    case triangle = "A0 · Small accent triangle (today)"
    case symbol = "A1 · ▶ in the gutter's grey, accent on hover"
    case hover = "A2 · Only while the pointer is in the gutter"
    case hidden = "A3 · None"

    var summary: String {
        switch self {
        case .triangle: "A drawn 6.8 × 8pt triangle at the gutter's left edge on the statement's first line."
        case .symbol: "The play.fill symbol, quiet until you point at it."
        case .hover: "Hidden until the pointer enters the gutter."
        case .hidden: "Run Statement at Cursor stays in Run's menu and the Query menu."
        }
    }
}

enum LabQEWordHighlight: String, CaseIterable {
    case today = "H0 · Selection colour, full line (today)"
    case soft = "H1 · Soft rounded tint"
    case underline = "H2 · Underline"
    case off = "H3 · Off"

    var summary: String {
        switch self {
        case .today: "Every other use of the word at the caret gets the selection colour at 30%, the whole line high and square."
        case .soft: "A grey tint as high as the letters, with the marks' corner: Xcode's way."
        case .underline: "A thin underline under each use."
        case .off: "No highlight."
        }
    }
}

enum LabQEMarkCorner: String, CaseIterable {
    case c0 = "0pt (today)"
    case c3 = "3pt"
    case c5 = "5pt"

    var points: CGFloat { self == .c0 ? 0 : self == .c3 ? 3 : 5 }
}

enum LabQEMarkHeight: String, CaseIterable {
    case line = "The whole line (today)"
    case letters = "The letters' height"
}

enum LabQEErrorWord: String, CaseIterable {
    case glow = "E0 · Glowing frame (today, while typing)"
    case squiggle = "E1 · Red squiggle"
    case fill = "E2 · Soft red tint"
    case dotted = "E3 · Dotted underline"

    var summary: String {
        switch self {
        case .glow: "Three blurred strokes of a red gradient that keeps shifting, 6pt corners. After a run the same error is a squiggle instead."
        case .squiggle: "The squiggle Echo already draws for a server error after a run, now for every error."
        case .fill: "A light red tint behind the word."
        case .dotted: "The macOS spelling mark: a red dotted line."
        }
    }
}

enum LabQEErrorMessage: String, CaseIterable {
    case pill = "M0 · Pill at the line's end (today)"
    case text = "M1 · Red text at the line's end"
    case banner = "M2 · Banner to the edge"
    case hover = "M3 · In a bubble, on hover or with the caret on the line"

    var summary: String {
        switch self {
        case .pill: "Icon and message on a pink pill, 12pt after the line."
        case .text: "The message in small red text, no background."
        case .banner: "Xcode's inline issue: a red band from the line's end to the card's edge."
        case .hover: "Nothing at the line's end; the server-error bubble shows the message when you point at the word or put the caret on its line."
        }
    }
}

enum LabQEErrorDot: String, CaseIterable {
    case dot = "D0 · Red dot by the number (today)"
    case number = "D1 · The number turns red"
    case nothing = "D2 · Nothing in the gutter"
}

enum LabQERunNoteLook: String, CaseIterable {
    case today = "R0 · Green text (today)"
    case quiet = "R1 · Grey text, green ✓"
    case capsule = "R2 · Tinted capsule"
    case glass = "R3 · Glass capsule"

    var summary: String {
        switch self {
        case .today: "“✓ 200 rows · 10.1 s” in 11pt green, 20pt after the last character."
        case .quiet: "Only the ✓ (or !) carries the colour; the numbers read as information, not as an alarm."
        case .capsule: "The note on a faint green or red capsule."
        case .glass: "The note on a glass capsule."
        }
    }
}

enum LabQERunNotePlace: String, CaseIterable {
    case lineEnd = "P0 · After the last line that ran (today)"
    case rightEdge = "P1 · At the card's right edge"

    var summary: String {
        self == .lineEnd ? "Right after the code, so the eye finds it where it was looking."
            : "Lined up on the right, like inline blame in other editors; never sits on top of long lines."
    }
}

enum LabQERanHighlight: String, CaseIterable {
    case nothing = "H0 · Nothing (today)"
    case flash = "H1 · A short flash when it starts"
    case outline = "H2 · Outline until you edit"
    case tint = "H3 · Tint until you edit"

    var summary: String {
        switch self {
        case .nothing: "Only the note says what ran."
        case .flash: "What ran lights up in the accent for a moment as the run starts, then fades."
        case .outline: "A thin accent outline round what ran, gone on the first edit."
        case .tint: "A faint accent tint on what ran, gone on the first edit."
        }
    }
}

enum LabQEZoomPlace: String, CaseIterable {
    case bottomLeft = "Z1 · Bottom left of the editor"
    case bottomRight = "Z2 · Bottom right of the editor"
    case footer = "Z3 · In the footer, by the connection"
    case keysOnly = "Z4 · Keys only, with a brief bezel"

    var summary: String {
        switch self {
        case .bottomLeft: "Where SSMS has it; over the gutter, which is narrow and calm."
        case .bottomRight: "Where lines rarely reach, under the scroll bar's end."
        case .footer: "Next to the server · database chip, as a third pill."
        case .keysOnly: "No control: ⌘+, ⌘− and ⌘0 (and pinch), with “125%” shown for a moment in the middle."
        }
    }
}

enum LabQEZoomLook: String, CaseIterable {
    case stepper = "L1 · − 100% +"
    case menu = "L2 · 100% with a menu"
    case magnifier = "L3 · Magnifier and percent"
}

enum LabQEZoomShows: String, CaseIterable {
    case always = "V0 · Always"
    case notDefault = "V1 · Only when not 100%"
    case hover = "V2 · While the pointer is over the editor"
}

enum LabQEZoomLevel: String, CaseIterable {
    case z50 = "50%", z75 = "75%", z90 = "90%", z100 = "100%", z110 = "110%", z125 = "125%", z150 = "150%", z200 = "200%"

    var scale: CGFloat { CGFloat(Int(rawValue.dropLast()) ?? 100) / 100 }
}
