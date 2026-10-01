import SwiftUI

// Round 28: the choices for the editor's text, gutter, caret line and selection. Names are the
// ids the owner's picks are saved under: never rename a case's raw value.

enum LabQELineHeight: String, CaseIterable {
    case today = "L0 · 31pt (today)"
    case natural = "L1 · 17pt, the font's own"
    case comfortable = "L2 · 20pt, 1.55 × the size"
    case relaxed = "L3 · 23pt, 1.75 × the size"

    /// The height of one line, as Echo's `SQLLayoutManager` computes it today and as each choice would.
    func height(size: CGFloat, natural: CGFloat) -> CGFloat {
        switch self {
        case .today: ceil(natural * 1.55 + size * 0.2 * 1.55)
        case .natural: ceil(natural)
        case .comfortable: (size * 1.55).rounded()
        case .relaxed: (size * 1.75).rounded()
        }
    }

    var summary: String {
        switch self {
        case .today: "The Line Spacing setting (1.55) is applied twice: the font's height × 1.55, plus 1.55 × 20% of the size again."
        case .natural: "No added space: the font's own line height, as Xcode and Terminal draw by default."
        case .comfortable: "What the design board meant by 1.55: a line 1.55 times the font size, as on the web."
        case .relaxed: "More air for presenting or large screens."
        }
    }
}

enum LabQEFontSize: String, CaseIterable {
    case s12 = "12pt"
    case s13 = "13pt (today)"
    case s14 = "14pt"

    var points: CGFloat { self == .s12 ? 12 : self == .s13 ? 13 : 14 }
}

enum LabQELigatures: String, CaseIterable {
    case on = "On (today)"
    case off = "Off"

    var summary: String {
        self == .on ? ">=, <> and != draw as ≥, ≠ and ≠: <> and != look the same."
            : "Every character as typed; <> and != stay different."
    }
}

enum LabQECodeGap: String, CaseIterable {
    case today = "21pt (today)"
    case g16 = "16pt"
    case g12 = "12pt"

    /// From the right edge of the numbers to the first character of code.
    var points: CGFloat { self == .today ? 21 : self == .g16 ? 16 : 12 }
}

enum LabQETopMargin: String, CaseIterable {
    case today = "4pt (today)"
    case m8 = "8pt"
    case m12 = "12pt"

    var points: CGFloat { self == .today ? 4 : self == .m8 ? 8 : 12 }
}

enum LabQEGutterSurface: String, CaseIterable {
    case subtle = "G0 · Numbers only (today's default)"
    case column = "G1 · Column"
    case lane = "G2 · Lane"
    case hairline = "G3 · A hairline only"

    var summary: String {
        switch self {
        case .subtle: "No surface; the numbers float on the card."
        case .column: "A faint full-height column with a 0.5pt edge (a setting today)."
        case .lane: "The same colour as a rounded lane inset 5pt (a setting today)."
        case .hairline: "No fill, only the 0.5pt edge between numbers and code."
        }
    }
}

enum LabQENumberFont: String, CaseIterable {
    case today = "N0 · SF digits, always 11pt (today)"
    case smaller = "N1 · SF digits, 2pt under the code"
    case codeFont = "N2 · The code's font, 2pt under"
    case same = "N3 · The code's font and size"

    var summary: String {
        switch self {
        case .today: "Fixed at 11pt: at 16pt code (or zoomed) the numbers stay small and drift off the code's rhythm."
        case .smaller: "Scales with the font size and zoom, stays quieter than the code."
        case .codeFont: "Numbers in the same face as the code, so they look like part of the script."
        case .same: "Numbers exactly like the code; loudest."
        }
    }
}

enum LabQENumberColour: String, CaseIterable {
    case palette = "C0 · Palette grey (today)"
    case tertiary = "C1 · Tertiary label"
    case secondary = "C2 · Secondary label"

    var summary: String {
        switch self {
        case .palette: "Aurora #6D6D6D, Midnight #858585: fixed greys from the theme."
        case .tertiary: "The system's tertiary label: quiet, and it follows Increase Contrast."
        case .secondary: "The system's secondary label: easier to read, louder."
        }
    }
}

enum LabQECurrentNumber: String, CaseIterable {
    case today = "K0 · Semibold in the palette's accent (today)"
    case primary = "K1 · Primary colour"
    case accent = "K2 · Accent colour"
    case same = "K3 · No difference"

    var summary: String {
        switch self {
        case .today: "The palette's “gutter accent” is #D9D9DC in light and #2D2D30 in dark: the caret's number is the faintest one."
        case .primary: "The caret's number in the text colour, the others grey: Xcode's way. Same weight, so nothing shifts."
        case .accent: "The caret's number in the accent colour."
        case .same: "Every number alike."
        }
    }
}

enum LabQEMarkerPlace: String, CaseIterable {
    case left = "M0 · A column left of the numbers (today)"
    case onNumber = "M1 · On the number"
    case between = "M2 · Between the numbers and the code"

    var summary: String {
        switch self {
        case .left: "11pt kept free on every line for the error dot and the Run arrow."
        case .onNumber: "An error line's number turns red; the Run arrow takes the number's place on its line. Narrowest."
        case .between: "The dot and arrow sit in the gap before the code, as VS Code's glyph margin."
        }
    }
}

enum LabQECurrentLine: String, CaseIterable {
    case band = "CL0 · Rounded band (today)"
    case noBand = "CL1 · None"
    case fullWidth = "CL2 · Full-width band"
    case outline = "CL3 · Hairline outline"

    var summary: String {
        switch self {
        case .band: "A grey band inset 6pt, corner 6pt, behind the caret's line while nothing is selected."
        case .noBand: "Nothing behind the text; the caret and its line number show where you are."
        case .fullWidth: "Xcode's optional highlight: a faint band from the gutter to the edge, square."
        case .outline: "A 0.5pt outline instead of a fill, so nothing tints the text."
        }
    }
}

enum LabQESelectionColour: String, CaseIterable {
    case palette = "S0 · Palette blue (today)"
    case system = "S1 · System selection colour"
    case accent = "S2 · Accent at 25%"

    var summary: String {
        switch self {
        case .palette: "Aurora #CCE8FF, Midnight #264F78: the same blue whatever the accent colour."
        case .system: "selectedTextBackgroundColor: follows the accent colour and turns grey when the window is in the background, like every text field."
        case .accent: "A lighter accent wash."
        }
    }
}

enum LabQESelectionShape: String, CaseIterable {
    case square = "Square (today)"
    case rounded = "Rounded 3pt"
}

enum LabQECaretColour: String, CaseIterable {
    case operatorColour = "I0 · The palette's operator colour (today)"
    case accent = "I1 · System accent"
    case text = "I2 · Text colour"

    var summary: String {
        switch self {
        case .operatorColour: "Near-black in light, blue (#569CD6) in dark: a side effect of using the operator's colour."
        case .accent: "The macOS insertion point: the accent colour, as in every text field since macOS 14."
        case .text: "The code's own colour."
        }
    }
}
