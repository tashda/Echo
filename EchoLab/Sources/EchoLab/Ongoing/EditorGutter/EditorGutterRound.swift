import SwiftUI

/// Round 28.2 · Editor: gutter. Echo today (LineNumberRulerView): SF digits fixed at 11pt in the
/// palette's grey, the caret line's number semibold in the palette's “gutter accent” (#D9D9DC in
/// Aurora, #2D2D30 in Midnight, so it is the faintest number), an 11pt column for the error dot
/// and Run arrow left of the numbers, and the Subtle, Column or Lane surface. Changes EDT-2.1 to 2.3.
@MainActor
enum EditorGutterRound {
    static let spec = RoundSpec(
        controls: [
            .of("currentNumber", "The caret line's number", LabQECurrentNumber.self, default: .primary,
                question: "Look at line 5's number in Echo today and in the Proposal, in light and dark. How should the caret line's number stand out?",
                recommend: .primary,
                why: "Today it is a bug: the palette's “gutter accent” was meant as a fill, so the number you are on is the faintest one. Xcode's way, the text colour on a grey column, says “you are here” without colour or weight; semibold makes the digits change width, and the accent competes with the selection and Run's accent.",
                summary: \.summary),
            .of("numberColour", "Number colour", LabQENumberColour.self, default: .tertiary,
                question: "Compare the numbers' colour with the code. Which grey should the numbers have?",
                recommend: .tertiary,
                why: "Tertiary label is quiet enough that the code leads, follows dark mode and Increase Contrast by itself, and leaves room for the current line's number to step up to the text colour. The palette's #6D6D6D is nearly as dark as the code in light mode.",
                summary: \.summary),
            .of("numberFont", "Number font", LabQENumberFont.self, default: .smaller,
                question: "Set the text page's size to 14pt in your head: which numbers keep up? Pick the numbers' font and size.",
                recommend: .smaller,
                why: "Today's numbers stay 11pt whatever the code's size, so zoom (page 28.8) would leave them behind. 2pt under the code keeps the gutter quieter and scales with it; SF digits stay tabular in every editor font. The code's own face is nice with JetBrains Mono but looks odd with fonts whose digits are wide.",
                summary: \.summary),
            .of("gutter", "Surface", LabQEGutterSurface.self, default: .subtle,
                question: "Look at the gallery. Which surface should the default be? (Column and Lane stay settings unless the settings page says otherwise.)",
                recommend: .subtle,
                why: "You chose Subtle as the default on the design board. With quiet numbers and no current-line band the gutter needs no surface; a hairline is the next best if the numbers ever feel loose.",
                summary: \.summary),
            .of("markers", "Error dot and Run arrow", LabQEMarkerPlace.self, default: .left,
                question: "Switch The editor shows to A mistake while typing. Where should the error dot and Run arrow sit?",
                recommend: .left,
                why: "A column of their own means a dot or an arrow never moves the numbers or the code, and the arrow never covers the number you might want to click. On the number is the narrowest, but a red number reads as a different line number; between the numbers and the code pushes the code right by 11pt on every line.",
                summary: \.summary),
            LabQERound.sceneControl(default: .typing),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("SF digits 11pt in #6D6D6D, the caret's line semibold in #D9D9DC, dot and arrow in an 11pt column on the left, no surface (Subtle).", scene: .typing),
            LabQERound.proposal("Built from the controls; the rest of the editor as you choose under Rest of the editor.", scene: .typing),
            LabQERound.gallery("Surfaces", "Every gutter surface on the proposal.", LabQEGutterSurface.self, \.gutter, scene: .typing),
        ],
        questions: [
            .init(id: "wrapped", title: "Wrapped lines",
                  question: "A long line wraps onto a second row. What should the gutter show beside the continuation?",
                  choices: [
                      .init(id: "blank", name: "W0 · Nothing (today)", summary: "One number per line of the script; continuations stay blank."),
                      .init(id: "arrow", name: "W1 · A faint ↪", summary: "Marks that the row continues the line above."),
                  ],
                  recommended: "blank",
                  why: "The blank already says it, and Xcode and SSMS draw nothing there; a symbol on every wrapped row adds noise to long WHERE clauses."),
            .init(id: "click", title: "Clicking a number",
                  question: "What should a click on a line number do?",
                  choices: [
                      .init(id: "select", name: "C0 · Select the line, drag for more (today)"),
                      .init(id: "breakpoint", name: "C1 · Nothing yet; keep it for breakpoints later"),
                  ],
                  recommended: "select",
                  why: "Selecting lines from the gutter is what every editor does and you use it to run part of a script; breakpoints (SSMS's debugger) can take the dot column if they ever come."),
        ],
        exhibitTopic: ("Which gutter?", "Look at the numbers in light and dark, then type in your head on line 5. Is the proposal better than Echo today?", "proposal",
                       "The number you are on is the clearest one, the others recede, and the gutter keeps step with the code's size."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Primary current number, tertiary numbers, SF 2pt under the code, no surface, markers left.",
                  values: ["currentNumber": LabQECurrentNumber.primary.rawValue, "numberColour": LabQENumberColour.tertiary.rawValue,
                           "numberFont": LabQENumberFont.smaller.rawValue, "gutter": LabQEGutterSurface.subtle.rawValue, "markers": LabQEMarkerPlace.left.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["currentNumber": LabQECurrentNumber.today.rawValue, "numberColour": LabQENumberColour.palette.rawValue,
                           "numberFont": LabQENumberFont.today.rawValue, "gutter": LabQEGutterSurface.subtle.rawValue, "markers": LabQEMarkerPlace.left.rawValue]),
            .init(id: "xcode", name: "Like Xcode", summary: "A column, the numbers in the code's font, the current one in the text colour.",
                  values: ["currentNumber": LabQECurrentNumber.primary.rawValue, "numberColour": LabQENumberColour.tertiary.rawValue,
                           "numberFont": LabQENumberFont.codeFont.rawValue, "gutter": LabQEGutterSurface.column.rawValue, "markers": LabQEMarkerPlace.onNumber.rawValue]),
        ]
    )
}
