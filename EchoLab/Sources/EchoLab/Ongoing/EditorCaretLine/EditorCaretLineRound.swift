import SwiftUI

/// Round 28.3 · Editor: caret, current line and selection. Echo today (SQLTextView+StatementFocus,
/// the Aurora/Midnight palettes): a grey rounded band behind the caret's line (inset 6pt, corner
/// 6pt) while nothing is selected, the palette's fixed blue selection, and the caret in the
/// palette's operator colour (near-black in light, blue in dark). Changes EDT-2.4.
@MainActor
enum EditorCaretLineRound {
    static let spec = RoundSpec(
        controls: [
            .of("currentLine", "Current line", LabQECurrentLine.self, default: LabQECurrentLine.noBand,
                question: "Click through the gallery, then type in your head on line 5 of the Proposal. What, if anything, should mark the caret's line?",
                recommend: LabQECurrentLine.noBand,
                why: "You said you hate the band, and it is the busiest thing on screen while you type: it moves on every arrow key and sits under the statement band and the word highlights. The caret and its line number (page 28.2, in the text colour) already say where you are; Xcode ships with the highlight off too.",
                summary: \.summary),
            .of("selectionColour", "Selection colour", LabQESelectionColour.self, default: .system,
                question: "Set The editor shows to Text selected, then Window in the background. Which selection colour?",
                recommend: .system,
                why: "The system's selection follows your accent colour and turns grey when the window is behind another, so a selection in Echo looks like one in every Mac app. The palette's blue ignores the accent and stays bright in the background.",
                summary: \.summary),
            .of("selectionShape", "Selection shape", LabQESelectionShape.self, default: .square,
                question: "With Text selected, compare square and rounded. Which shape?",
                recommend: .square,
                why: "NSTextView draws square selections that join line to line; rounded ends leave notches between rows of a multi-line selection and would be ours to maintain."),
            .of("caret", "Caret colour", LabQECaretColour.self, default: .accent,
                question: "Look at the caret on line 5 in light and dark. Which colour?",
                recommend: .accent,
                why: "macOS draws the insertion point in the accent colour in every text field; Echo overrides it with the operator colour by accident, which is why it turns blue in dark mode and black in light.",
                summary: \.summary),
            LabQERound.sceneControl(default: .typing),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("A rounded grey band on line 5, the system's selection (corrected: the page first said the palette's blue), the caret in the operator colour.", scene: .typing, before28: true),
            LabQERound.proposal("Built from the controls; the rest of the editor as you choose under Rest of the editor.", scene: .typing),
            LabQERound.gallery("Current line", "Every current-line choice on the proposal.", LabQECurrentLine.self, \.currentLine, scene: .typing),
        ],
        questions: [
            .init(id: "blink", title: "Blinking",
                  question: "Should the caret blink?",
                  choices: [
                      .init(id: "system", name: "B0 · As the system sets it (today)", summary: "Blinks, unless Reduce Motion or the accessibility setting stops it."),
                      .init(id: "steady", name: "B1 · Always steady"),
                  ],
                  recommended: "system",
                  why: "It is a system preference (Accessibility › Display › Prefer non-blinking cursor); Echo should follow it, not decide it."),
            .init(id: "focus", title: "When the editor isn't focused",
                  question: "You click into the results or the tree. What should the editor keep showing?",
                  choices: [
                      .init(id: "system", name: "U0 · Grey selection, no caret (native)"),
                      .init(id: "keep", name: "U1 · Selection stays in colour"),
                  ],
                  recommended: "system",
                  why: "Grey says the keyboard is somewhere else, which matters when ⌘C could copy from the grid or from the editor."),
        ],
        exhibitTopic: ("Which caret line?", "Type in your head, select, and send the window to the back. Is the proposal better than Echo today?", "proposal",
                       "Nothing tints the text you are typing, and the selection and caret behave like every other Mac text view."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "No band, system selection, square, accent caret.",
                  values: ["currentLine": LabQECurrentLine.noBand.rawValue, "selectionColour": LabQESelectionColour.system.rawValue,
                           "selectionShape": LabQESelectionShape.square.rawValue, "caret": LabQECaretColour.accent.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["currentLine": LabQECurrentLine.band.rawValue, "selectionColour": LabQESelectionColour.palette.rawValue,
                           "selectionShape": LabQESelectionShape.square.rawValue, "caret": LabQECaretColour.operatorColour.rawValue]),
            .init(id: "xcode", name: "Like Xcode with the highlight on",
                  values: ["currentLine": LabQECurrentLine.fullWidth.rawValue, "selectionColour": LabQESelectionColour.system.rawValue,
                           "selectionShape": LabQESelectionShape.square.rawValue, "caret": LabQECaretColour.accent.rawValue]),
        ]
    )
}
