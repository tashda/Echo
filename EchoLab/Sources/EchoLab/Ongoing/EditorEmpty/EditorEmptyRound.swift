import SwiftUI

/// Round 28.10 · Editor: empty tab and the right edge. Echo today: an empty tab shows “Start
/// typing, or begin with a recent table or a snippet” in 13pt tertiary with up to 4 recent tables
/// and 4 snippets as chips, 52pt from the left and 32pt from the top (QE6, EmptyQueryHints), so it
/// lines up with neither the code nor its first line. The Outline Edge setting (QE5, off) puts a
/// strip of statements and errors on the right edge in place of the scroll bar. Changes EDT-1.3.
@MainActor
enum EditorEmptyRound {
    static let spec = RoundSpec(
        controls: [
            .of("hints", "Where the starting points sit", LabQEHintsPlace.self, default: .firstLine,
                question: "Compare the empty tab in both. Where should the prompt and chips start?",
                recommend: .firstLine,
                why: "The prompt is a placeholder for what you are about to type, so it should start exactly where the caret blinks, in the code's font, like a text field's placeholder; today it floats 6pt right of the code and a line and a half down, so the caret and the prompt sit apart.",
                summary: \.summary),
            LabQERound.baseControl,
        ],
        exhibits: [
            .init(id: "today", title: "Echo before round 28", summary: "The prompt and chips 52pt in and 32pt down, in the system font.", isEchoToday: true,
                  designWidth: LabQERound.width, designHeight: 260) { _ in
                LabQEEditor(style: .before28, scene: LabQEScene(empty: true), hints: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Where the control puts them.", designWidth: LabQERound.width, designHeight: 260) { values in
                LabQEEditor(style: LabQEBase.proposal(values), scene: LabQEScene(empty: true), hints: LabQEHintsPlace(rawValue: values["hints"]) ?? .firstLine)
            },
            .init(id: "outline", title: "Outline edge (a setting, off)", summary: "The proposal with Outline Edge on, while typing a mistake: statements in grey, the error in red, the visible part in the accent.",
                  designWidth: LabQERound.width, designHeight: LabQERound.height) { values in
                LabQEEditor(style: LabQEBase.proposal(values), scene: LabQESceneChoice.liveError.scene, outlineEdge: true)
            },
        ],
        questions: [
            .init(id: "chips", title: "What an empty tab offers",
                  question: "QE6 was accepted and built: recent tables, then snippets. Keep both rows?",
                  choices: [
                      .init(id: "both", name: "EC0 · Recent tables and snippets (today)"),
                      .init(id: "tables", name: "EC1 · Recent tables only", summary: "Snippets stay in the Snippets sidebar and EchoSense."),
                      .init(id: "prompt", name: "EC2 · The prompt only"),
                  ],
                  recommended: "both",
                  why: "You accepted it on the design board, and both rows go the moment you type; a recent table is the commonest way a query starts."),
            .init(id: "outlineEdge", title: "Outline edge",
                  question: "Keep the outline edge as a setting, off by default (QE5)?",
                  choices: [
                      .init(id: "setting", name: "OE0 · A setting, off (today)"),
                      .init(id: "on", name: "OE1 · On for everyone"),
                      .init(id: "drop", name: "OE2 · Remove it"),
                  ],
                  recommended: "setting",
                  why: "It earns its place in long scripts with errors, but on a 10-line query it is a strip of chrome where the scroll bar would hide itself. As a setting it costs nothing."),
            .init(id: "scroller", title: "The scroll bar",
                  question: "Without the outline edge, the editor uses the system's overlay scroll bar, shown while scrolling. Keep it?",
                  choices: [
                      .init(id: "overlay", name: "SB0 · The system's overlay scroll bar (today)"),
                      .init(id: "always", name: "SB1 · Always visible"),
                  ],
                  recommended: "overlay",
                  why: "It follows the system's Show scroll bars setting, which is the user's choice, not Echo's; round 27 decides the results grid's bars separately."),
        ],
        exhibitTopic: ("Which empty tab?", "Look at where the prompt sits against where you would type. Is the proposal better than Echo today?", "proposal",
                       "The prompt starts where the caret is, so the first thing you type replaces it in place."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "On the first line.", values: ["hints": LabQEHintsPlace.firstLine.rawValue], isRecommended: true),
            .init(id: "today", name: "Like Echo today", values: ["hints": LabQEHintsPlace.today.rawValue]),
        ]
    )
}
