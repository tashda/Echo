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
    case topCapsule = "FB4 · One glass capsule, top centre"
    case safari = "FB5 · A capsule with glass buttons beside it"
    case immersiveStrip = "FB6 · FB2 made immersive"
    case corner = "FB7 · A compact capsule, top right"
    case bottomCapsule = "FB8 · A capsule at the bottom centre"
    case notch = "FB9 · A glass tab from the card's top edge"
    case spotlight = "FB10 · Spotlight, with the matches listed"

    /// Rev 2: the owner liked FB2 but asked for an immersive glass search capsule and many more ideas.
    static let addedInRev2: [LabQEFindBarPlace] = [.topCapsule, .safari, .immersiveStrip, .corner, .bottomCapsule, .notch, .spotlight]

    /// The rev 2 looks draw the text straight on the glass, with no white field.
    var isImmersive: Bool { Self.addedInRev2.contains(self) }

    var summary: String {
        switch self {
        case .topCapsule: "Magnifier, the search, the count, ‹ › and × in one Liquid Glass capsule floating at the top centre; the text sits on the glass."
        case .safari: "The search in a glass capsule, with ‹ › and × as round glass buttons beside it that melt into it, like Safari 26's toolbar."
        case .immersiveStrip: "Your FB2 strip, with the field melted into the glass: no white box, the text and count on the glass itself."
        case .corner: "A small glass capsule tucked into the top-right corner; the count and arrows inside it."
        case .bottomCapsule: "A glass capsule at the bottom centre, above the footer, near your hands' focus after typing."
        case .notch: "A glass tab that hangs from the card's top edge, as if pulled down from the tab bar."
        case .spotlight: "A larger glass capsule like Spotlight, with the matching lines listed under it; click one to jump."
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

/// Rev 2: how Replace works.
enum LabQEReplaceStyle: String, CaseIterable {
    case secondRow = "RP0 · A second row (today)"
    case expand = "RP1 · A chevron opens it inside the capsule"
    case ownCapsule = "RP2 · Its own capsule beside find"
    case preview = "RP3 · A second row, and every match shows its replacement"

    var summary: String {
        switch self {
        case .secondRow: "Replace opens a second row under the find field, with Replace and All."
        case .expand: "A small chevron at the find field's start opens the replace field inside the same capsule, as in VS Code."
        case .ownCapsule: "Replace is a second glass capsule beside the first, with its own Replace and All."
        case .preview: "While you type the replacement, each match shows it in green over the old text in red, before anything changes."
        }
    }
}

/// Rev 2: what find searches.
enum LabQEFindScope: String, CaseIterable {
    case editor = "SS0 · The whole script (today)"
    case selectionAuto = "SS1 · The selection, when it spans lines"
    case selectionToggle = "SS2 · An In Selection button"
    case segmented = "SS3 · Script, Statement or Selection"
    case selectionButton = "SS4 · A Selection button that appears with a selection, on"

    var summary: String {
        switch self {
        case .editor: "Always the whole script."
        case .selectionAuto: "Select several lines and press ⌘F: only they are searched, and the bar says “in selection”; select a word and it becomes the search instead."
        case .selectionToggle: "A small button in the bar limits the search to the selection; off by default."
        case .segmented: "A small three-way switch in the bar: the whole script, the statement at the caret, or the selection."
        case .selectionButton: "Your design (rev 3): with nothing selected there is no button; select text and a Selection button appears, already on in the accent, so the search stays inside it; click it to search the whole script."
        }
    }
}

enum LabQEFindCount: String, CaseIterable {
    case found = "C0 · “2 found” (today)"
    case position = "C1 · “1 of 2”"
}
