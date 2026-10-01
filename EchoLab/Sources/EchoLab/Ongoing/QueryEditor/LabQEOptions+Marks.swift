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
    case c2 = "2pt"
    case c4 = "4pt"
    case c6 = "6pt"
    case followSelection = "Follows Selection Corners"

    /// Rev 2: the owner asked for more options. Following the selection's setting uses its
    /// default (3pt) in the specimen.
    var points: CGFloat {
        switch self {
        case .c0: 0
        case .c2: 2
        case .c3, .followSelection: 3
        case .c4: 4
        case .c5: 5
        case .c6: 6
        }
    }

    var summary: String {
        self == .followSelection ? "Every mark on the text takes Settings › Selection Corners (Square, 2, 3, 4 or 6pt; 3pt by default), so marks and the selection always match."
            : "A fixed radius for every mark on the text."
    }
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
    case boldSquiggle = "E4 · Bold squiggle"
    case doubleUnderline = "E5 · Double underline"
    case redLetters = "E6 · Red letters"
    case redLettersSquiggle = "E7 · Red letters and a squiggle"
    case cornerTicks = "E8 · Corner ticks"
    case underBar = "E9 · A bar under the word"
    case pill = "E10 · Tinted pill"
    case dashedOutline = "E11 · Dashed outline"
    case marker = "E12 · Marker stroke"

    /// Rev 3: the owner asked for everything, with and without a glow.
    static let addedInRev3: [LabQEErrorWord] = [.boldSquiggle, .doubleUnderline, .redLetters, .redLettersSquiggle, .cornerTicks, .underBar, .pill, .dashedOutline, .marker]

    var summary: String {
        switch self {
        case .boldSquiggle: "A 1.5pt squiggle with a longer wave: easier to see on a big screen."
        case .doubleUnderline: "Two thin red lines under the word, like a proofreader's mark."
        case .redLetters: "The word itself turns red; nothing else is drawn."
        case .redLettersSquiggle: "Red letters with the squiggle under them: the strongest of the quiet marks."
        case .cornerTicks: "Four small red corners round the word, like a camera's focus frame."
        case .underBar: "A solid 2pt red bar under the letters, rounded at the ends."
        case .pill: "A red-tinted capsule behind the word."
        case .dashedOutline: "A thin dashed red outline with the marks' corner."
        case .marker: "A red highlighter stroke across the lower half of the letters."
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
    case faintCapsule = "R4 · Faint capsule, grey numbers"
    case outlined = "R5 · Outlined capsule"
    case solid = "R6 · Solid capsule"
    case symbolCapsule = "R7 · Capsule with a symbol"
    case tintedGlass = "R8 · Tinted glass"
    case clearGlass = "R9 · Clear glass, coloured ✓"
    case glassSymbol = "R10 · Glass with a symbol"

    /// Rev 2: the owner asked for more capsules, glass among them.
    static let addedInRev2: [LabQERunNoteLook] = [.faintCapsule, .outlined, .solid, .symbolCapsule, .tintedGlass, .clearGlass, .glassSymbol]

    var summary: String {
        switch self {
        case .faintCapsule: "R2's capsule at half the tint, with only the ✓ coloured and the numbers grey."
        case .outlined: "No fill: a hairline capsule in the result's colour."
        case .solid: "A filled capsule in green or red with white text; the loudest."
        case .symbolCapsule: "A faint capsule with checkmark.circle.fill (or the error symbol) instead of ✓."
        case .tintedGlass: "Glass tinted with the result's colour."
        case .clearGlass: "Clear glass over the code; the ✓ carries the colour."
        case .glassSymbol: "Glass with the symbol and grey numbers."
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
    case bracketPulse = "H4 · The gutter bracket lights up"
    case gentleTint = "H5 · A gentle tint that fades"
    case outlineFade = "H6 · An outline that fades"
    case sweep = "H7 · A light passes down what ran"
    case edgeGlow = "H8 · A soft glow at the left edge"
    case gutterLine = "H9 · A line in the gutter that fades"

    /// Rev 2: the flash was too much; more, quieter options.
    static let addedInRev2: [LabQERanHighlight] = [.bracketPulse, .gentleTint, .outlineFade, .sweep, .edgeGlow, .gutterLine]

    var summary: String {
        switch self {
        case .bracketPulse: "The statement's bracket beside the numbers (28.4) turns solid and a little wider, then settles back; the text is never tinted."
        case .gentleTint: "A third of the flash's tint, fading over 2 s."
        case .outlineFade: "A thin accent outline round what ran, fading over 1.5 s."
        case .sweep: "A soft band of light moves once from the first line to the last, as if reading it."
        case .edgeGlow: "A soft accent glow along the left edge of the lines that ran, fading over 1.5 s."
        case .gutterLine: "A 2pt accent line beside the numbers of what ran, fading over 2 s."
        case .nothing: "Only the note says what ran."
        case .flash: "What ran lights up in the accent for a moment as the run starts, then fades."
        case .outline: "A thin accent outline round what ran, gone on the first edit."
        case .tint: "A faint accent tint on what ran, gone on the first edit."
        }
    }
}

/// Round 28.7 rev 3: what the statement's bracket does while its query runs (the owner liked H4
/// and asked for it to pulse while running).
enum LabQERunningMark: String, CaseIterable {
    case nothing = "RR0 · Nothing while it runs (today)"
    case breathe = "RR1 · The bracket breathes"
    case travel = "RR2 · A light travels down the bracket"
    case shimmer = "RR3 · A shimmer runs along it"
    case glow = "RR4 · The bracket glows, steady"
    case march = "RR5 · Marching dashes"
    case grow = "RR6 · It fills from the top, again and again"

    var summary: String {
        switch self {
        case .nothing: "The toolbar's red Run and the timer are the only signs."
        case .breathe: "The bracket fades between half and full accent, once a second and a half, like a sleeping Mac's light."
        case .travel: "A bright spot slides from the statement's first line to its last, then starts again."
        case .shimmer: "A soft highlight sweeps along the bracket, the way a loading placeholder shimmers."
        case .glow: "The bracket turns solid with a soft accent glow round it until the result comes."
        case .march: "The bracket becomes dashes that move downwards, like a selection being made."
        case .grow: "The bracket draws itself from the top down, over and over, like an indeterminate progress bar."
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
