import SwiftUI

/// Round 28.11 · Editor: settings. Every editor setting Echo has today and where it lives
/// (AppearanceSettingsView, +EditorFont, EchoSenseSettingsView, QueryResultsSettingsView, and
/// GlobalSettings fields with no switch), against one Settings › Editor pane.
@MainActor
enum EditorSettingsRound {
    static let spec = RoundSpec(
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Editor settings over three panes, and five stored settings with no switch anywhere.",
                  isEchoToday: true, designWidth: 420, designHeight: 620) { _ in
                LabQESettingsMap()
            },
            .init(id: "proposal", title: "Proposal", summary: "One Settings › Editor pane, in the order you meet things in the editor, with the recommended defaults.",
                  designWidth: 420, designHeight: 620) { _ in
                LabQEEditorPane()
            },
        ],
        questions: [
            .init(id: "pane", title: "One pane",
                  question: "Should every editor setting live in one Settings › Editor pane?",
                  choices: [
                      .init(id: "one", name: "SP0 · One Editor pane", summary: "Completion-only settings stay in EchoSense; results settings stay in Query Results."),
                      .init(id: "spread", name: "SP1 · Where they are today"),
                  ],
                  recommended: "one",
                  why: "You said you get lost: today the font is under Appearance, the live check under EchoSense and the error note under Query Results. One pane, ordered as you meet things in the editor, answers “where is it?” with one place."),
            .init(id: "hidden", title: "Settings with no switch",
                  question: "Echo stores Show line numbers, Highlight the word at the caret, its delay, Wrap lines and the wrapped indent, but Settings shows none of them. Which get a switch?",
                  choices: [
                      .init(id: "three", name: "HS0 · Line numbers, word highlight and wrapping get switches; delay and indent stay fixed"),
                      .init(id: "all", name: "HS1 · All five"),
                      .init(id: "drop", name: "HS2 · None: remove them from the data"),
                  ],
                  recommended: "three",
                  why: "Those three are things people really turn off (presenting, a long generated query, reading someone's script); a highlight delay and an indent width are tuning nobody looks for."),
            .init(id: "gutterStyle", title: "Gutter style",
                  question: "Keep Subtle, Column and Lane as a setting (decided on the design board)?",
                  choices: [
                      .init(id: "keep", name: "GS0 · Keep the setting"),
                      .init(id: "drop", name: "GS1 · One gutter: what page 28.2 decides"),
                  ],
                  recommended: "keep",
                  why: "You made Column and Lane settings two days ago; with quieter numbers they matter less, but they are cheap to keep and some people want a visible edge."),
            .init(id: "statementFocus", title: "Statement focus",
                  question: "Keep Statement Focus as a switch (on)?",
                  choices: [
                      .init(id: "keep", name: "SF0 · Keep, on"),
                      .init(id: "off", name: "SF1 · Keep, off"),
                      .init(id: "drop", name: "SF2 · Always on, no switch"),
                  ],
                  recommended: "keep",
                  why: "With the bracket (page 28.4) it is quiet enough to be on for everyone, and anyone who never runs statement by statement can still turn it off."),
            .init(id: "liveCheck", title: "Live check",
                  question: "Live query validation is under EchoSense today. Where does it belong?",
                  choices: [
                      .init(id: "editor", name: "LC0 · Editor, under While typing"),
                      .init(id: "echosense", name: "LC1 · EchoSense (today)"),
                  ],
                  recommended: "editor",
                  why: "What you see is red marks in the editor; that EchoSense finds them is how it works, not where people look."),
            .init(id: "errorNote", title: "The error note",
                  question: "“Show the error's message in the run note” is under Query Results today. Where does it belong?",
                  choices: [
                      .init(id: "editor", name: "EN0 · Editor, under After a run"),
                      .init(id: "results", name: "EN1 · Query Results (today)"),
                  ],
                  recommended: "editor",
                  why: "The note is drawn in the editor, at the end of the statement."),
            .init(id: "theme", title: "Editor theme",
                  question: "Echo ships 20 editor palettes (Aurora, Solstice, Midnight, One Dark, Dracula, Nord …) but Settings has no way to pick one: everyone gets Aurora in light and Midnight in dark. What should happen?",
                  choices: [
                      .init(id: "picker", name: "TH0 · A Theme picker, one for light and one for dark"),
                      .init(id: "fixed", name: "TH1 · Keep Aurora and Midnight, drop the other 18"),
                  ],
                  recommended: "picker",
                  why: "The palettes are built and stored per appearance already; people who live in an editor all day expect to pick its colours, and DataGrip, Xcode and SSMS all let them. Dropping them throws away finished work."),
            .init(id: "sizePicker", title: "Font size",
                  question: "Font Size is a pop-up of 33 sizes from 8 to 24 in half points, written “13,0 pt”. How should it be picked?",
                  choices: [
                      .init(id: "popup", name: "FS0 · The pop-up (today)"),
                      .init(id: "whole", name: "FS1 · A pop-up of whole sizes, “13 pt”"),
                      .init(id: "stepper", name: "FS2 · A field with a stepper"),
                  ],
                  recommended: "whole",
                  why: "Half points make the list twice as long for differences you can't see at a glance, and “13,0 pt” is a formatting slip. Zoom covers in-between sizes for a moment."),
        ],
        exhibitTopic: ("Which settings?", "Find the font, the line numbers and the live check in both. Is the proposal easier to use than Echo today?", "proposal",
                       "Everything about the editor in one pane, in the order you meet it, and nothing stored without a switch.")
    )
}
