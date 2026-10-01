import SwiftUI

/// Round 28.7 · Editor: after a run (QE2, accepted on the design board). Echo today
/// (SQLTextView+RunNote, EchoSense's QueryRunNote): “✓ 200 rows · 10.1 s” in 11pt green, 20pt
/// after the last line that ran, gone at the first edit; red “! Error” for a failure, orange for
/// a cancel. Nothing marks what ran. The row count was wrong for big results: it counted the rows
/// read back into memory when the run ended (200 in the owner's screenshot), not the rows the server sent; it now
/// uses the footer's count (QueryEditorState.finishExecution). Changes EDT-3.3.
@MainActor
enum EditorRunNoteRound {
    static let spec = RoundSpec(
        controls: [
            .of("runNoteLook", "Look", LabQERunNoteLook.self, default: .quiet,
                question: "Compare the looks in the gallery and in light and dark. How should the note look?",
                recommend: .quiet,
                why: "A whole line of green shouts “success” on every SELECT, and it is the only coloured text in the code. Colour on the ✓ alone still tells success from failure at a glance, and the numbers read like the footer's. Capsules make the note look like a button; glass on content breaks your glass-for-controls rule.",
                summary: \.summary),
            .of("runNotePlace", "Place", LabQERunNotePlace.self, default: .lineEnd,
                question: "Should the note follow the code or line up at the right edge?",
                recommend: .lineEnd,
                why: "Right after the code is where your eye already is when you press ⌘↩, and the note can't be mistaken for a note on another line. The right edge lines up nicely but sits far from short statements, and on a narrow editor it lands on top of long lines.",
                summary: \.summary),
            .of("ranHighlight", "What ran", LabQERanHighlight.self, default: .flash,
                question: "Press Run again a few times with each choice. Should Echo show which part of the script ran?",
                recommend: .flash,
                why: "When you run a selection or the statement at the cursor, a moment's light on exactly what went to the server confirms it without staying in the way. An outline or tint that stays until you edit is clearer for a script, but it is one more mark on the text for the whole time you read the results.",
                summary: \.summary),
            LabQERound.sceneControl(default: .afterRun),
            LabQERound.baseControl,
        ],
        actions: [LabQERound.runAgain],
        exhibits: [
            LabQERound.today("“✓ 14,870 rows · 10.1 s” in green after line 8; nothing marks what ran.", scene: .afterRun),
            LabQERound.proposal("Built from the controls. Press Run again to see the flash.", scene: .afterRun),
            LabQERound.gallery("Looks", "Every look of the note, on the proposal.", LabQERunNoteLook.self, \.runNoteLook, scene: .afterRun),
        ],
        questions: [
            .init(id: "count", title: "The row count",
                  question: "Which count should the note give? (The bug: it said 200 rows for a result of 14,870.)",
                  choices: [
                      .init(id: "all", name: "RC0 · Every row the server sent (fixed now)", summary: "The same number as the footer."),
                      .init(id: "loaded", name: "RC1 · The rows loaded so far, then the total", summary: "“500 of 14,870 rows” while the grid catches up."),
                  ],
                  recommended: "all",
                  why: "The note is about the query, not the grid: the query returned 14,870 rows, and the footer already says how many are loaded. Built and covered by a test (QueryEditorStateRunNoteTests)."),
            .init(id: "wording", title: "Wording",
                  question: "How should the numbers read?",
                  choices: [
                      .init(id: "dot", name: "WD0 · 14,870 rows · 10.1 s (today)"),
                      .init(id: "in", name: "WD1 · 14,870 rows in 10.1 s"),
                  ],
                  recommended: "dot",
                  why: "The dot is how the footer and the script results list say it, so the same facts read the same everywhere."),
            .init(id: "lifetime", title: "When it goes",
                  question: "When should the note go away?",
                  choices: [
                      .init(id: "edit", name: "LT0 · At the first edit (today)"),
                      .init(id: "nextRun", name: "LT1 · At the next run"),
                      .init(id: "fade", name: "LT2 · After 10 s"),
                  ],
                  recommended: "edit",
                  why: "Once you edit, the note describes code that no longer exists; keeping it until the next run invites reading it as the new result. Fading after 10 s loses it during a long look at the results."),
            .init(id: "multi", title: "A script with several statements",
                  question: "You run the whole script (two statements). Where do the notes go?",
                  choices: [
                      .init(id: "each", name: "MS0 · One note after each statement"),
                      .init(id: "last", name: "MS1 · One note after the last line (today)", summary: "The total of the run; each statement's rows are in the results list."),
                  ],
                  recommended: "each",
                  why: "The point of the note is to tie a result to its code; with one note for the whole script you can't see that the UPDATE touched 0 rows while the SELECT returned 14,870. check: needs the per-statement results Echo already has for scripts (round 21)."),
        ],
        exhibitTopic: ("Which run note?", "Run again in both, in light and dark. Is the proposal better than Echo today?", "proposal",
                       "It says the same in calmer type, with the right count, and shows for a moment what actually ran."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Grey text with a green ✓ after the code; a short flash on what ran.",
                  values: ["runNoteLook": LabQERunNoteLook.quiet.rawValue, "runNotePlace": LabQERunNotePlace.lineEnd.rawValue, "ranHighlight": LabQERanHighlight.flash.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["runNoteLook": LabQERunNoteLook.today.rawValue, "runNotePlace": LabQERunNotePlace.lineEnd.rawValue, "ranHighlight": LabQERanHighlight.nothing.rawValue]),
            .init(id: "outlined", name: "Outlined", summary: "A capsule at the right edge, what ran outlined until you edit.",
                  values: ["runNoteLook": LabQERunNoteLook.capsule.rawValue, "runNotePlace": LabQERunNotePlace.rightEdge.rawValue, "ranHighlight": LabQERanHighlight.outline.rawValue]),
        ]
    )
}
