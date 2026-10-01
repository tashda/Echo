import SwiftUI

// Round 28 rev 2: how find matches are marked (28.5) and how the find bar looks (28.12). Never
// rename a case's raw value: the owner's picks are saved under it.

/// The look of find matches; the raw values are page 28.5's choice ids for its Find question.
enum LabQEFindLook: String, CaseIterable {
    case native
    case echo
    case yellow
    case accent
    case underline

    var title: String {
        switch self {
        case .native: "F0 · The system's find (today)"
        case .echo: "F1 · Echo's soft tint for every match"
        case .yellow: "F2 · A yellow tint for every match"
        case .accent: "F3 · An accent tint for every match"
        case .underline: "F4 · A yellow underline for every match"
        }
    }

    var summary: String {
        switch self {
        case .native: "While the find field has the keyboard, the rest of the text dims and every match stays lit; the current one gets the yellow bubble."
        case .echo: "Matches get the grey tint of the word at the caret; only the current one is yellow. Nothing dims."
        case .yellow: "Every match in a light yellow with the marks' corner; the current one solid yellow. Nothing dims."
        case .accent: "Every match in a light accent tint; the current one stronger, with an outline."
        case .underline: "Every match underlined in yellow; the current one solid yellow."
        }
    }
}

/// A control over the same looks (the page asks the question; this switches the preview).
enum LabQEFindPreview: String, CaseIterable {
    case native = "F0 · The system's find (today)"
    case echo = "F1 · Echo's soft tint"
    case yellow = "F2 · Yellow tint"
    case accent = "F3 · Accent tint"
    case underline = "F4 · Yellow underline"

    var look: LabQEFindLook {
        switch self {
        case .native: .native
        case .echo: .echo
        case .yellow: .yellow
        case .accent: .accent
        case .underline: .underline
        }
    }
}

enum LabQEFindBarPlace: String, CaseIterable {
    case native = "FB0 · The system's find bar (today)"
    case floating = "FB1 · Floating at the top right"
    case strip = "FB2 · A glass strip along the top"
    case bottom = "FB3 · Floating at the bottom"

    var summary: String {
        switch self {
        case .native: "NSTextView's bar above the text, the card's full width; it pushes the code down while it is open."
        case .floating: "A small glass panel over the code's top-right corner, as in SSMS, VS Code and Xcode 26's editor."
        case .strip: "A glass bar inside the card's top edge, inset like the toolbar's capsules; floats over the code."
        case .bottom: "A glass panel above the footer, where the zoom and the footer chips already are."
        }
    }
}

enum LabQEFindOptions: String, CaseIterable {
    case menu = "O0 · In the field's menu (today)"
    case toggles = "O1 · Aa, whole word and .* as buttons"

    var summary: String {
        self == .menu ? "Ignore Case, Contains / Starts With / Full Word behind the magnifier's menu; no regular expressions."
            : "Three small toggles at the field's end, always visible; regular expressions added."
    }
}

enum LabQEFindCount: String, CaseIterable {
    case found = "C0 · “2 found” (today)"
    case position = "C1 · “1 of 2”"
}
