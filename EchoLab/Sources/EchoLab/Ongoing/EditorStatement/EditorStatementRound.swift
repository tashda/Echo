import SwiftUI

/// Round 28.4 · Editor: the statement at the caret (QE1, accepted on the design board). Echo today
/// (SQLTextView+StatementFocus, LineNumberRulerView.drawRunArrow): with Statement Focus on and
/// two or more statements, a 6% accent band behind the statement from the gutter to the edge,
/// and an 8pt accent triangle in the gutter on its first line that runs it. A selected script
/// result lights its statement with the same band at 12% (round 21, SK2). Changes EDT-3.1, 3.2.
@MainActor
enum EditorStatementRound {
    static let spec = RoundSpec(
        controls: [
            .of("statement", "How the statement shows", LabQEStatementLook.self, default: .bracket,
                question: "Look at the gallery, then the Proposal. How should Echo show which statement Run Statement at Cursor (and the arrow) will run?",
                recommend: .bracket,
                why: "The band tints seven lines at once and moves with the caret, much like the current-line band you dislike, and stacks with selection and highlights. A thin bar beside the numbers says the same without touching the text. Hover-only is calmest, but you lose the hint before pressing ⌘↩ at Cursor.",
                summary: \.summary),
            .of("runArrow", "Run arrow", LabQERunArrow.self, default: .symbol,
                question: "Point at the gutter beside line 1 in the Proposal. How should the Run arrow look?",
                recommend: .symbol,
                why: "A grey arrow is there to find but doesn't pull the eye on every caret move; it turns accent under the pointer, like a button. Today's accent triangle is the brightest thing in the gutter; hover-only hides a feature you accepted; none drops it.",
                summary: \.summary),
            LabQERound.sceneControl(default: .typing),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("A 6% accent band behind lines 1 to 8 and an accent triangle on line 1.", scene: .typing, before28: true),
            LabQERound.proposal("Built from the controls; the rest of the editor as you choose under Rest of the editor.", scene: .typing),
            LabQERound.gallery("Statement looks", "Every way of showing the statement, on the proposal.", LabQEStatementLook.self, \.statement, scene: .typing),
        ],
        questions: [
            .init(id: "when", title: "When it shows",
                  question: "The script holds a single statement. Should the statement still be marked?",
                  choices: [
                      .init(id: "several", name: "W0 · Only with two or more statements (today)"),
                      .init(id: "always", name: "W1 · Always"),
                  ],
                  recommended: "several",
                  why: "With one statement, Run and Run Statement at Cursor do the same thing, so a mark says nothing new."),
            .init(id: "result", title: "A selected result's statement",
                  question: "In a script's results you select result 2, and Echo lights the statement it came from (SK2, today the band at 12%). How should that look?",
                  choices: [
                      .init(id: "band", name: "SR0 · The band at 12% (today)"),
                      .init(id: "follow", name: "SR1 · Like the statement look, in the accent", summary: "With the bracket: a solid bracket beside that statement."),
                      .init(id: "outline", name: "SR2 · A thin outline round the statement"),
                  ],
                  recommended: "follow",
                  why: "One way of saying “this statement” in the editor is easier to learn than two; the result's link is the stronger, solid version of the same mark, so they can still be told apart."),
            .init(id: "ends", title: "Where a statement ends",
                  question: "Echo ends a statement at a semicolon, a GO line or a blank line (EDT-3.4). Is that right?",
                  choices: [
                      .init(id: "today", name: "SE0 · Semicolon, GO or a blank line (today)"),
                      .init(id: "noBlank", name: "SE1 · Semicolon or GO only", summary: "A blank line inside a long query no longer splits it."),
                  ],
                  recommended: "today",
                  why: "Most scripts in SSMS have no semicolons, and a blank line between queries is how people separate them; a blank line inside one query is rarer and shows at once as a short band or bracket."),
        ],
        exhibitTopic: ("Which statement mark?", "Move the caret in your head between the two statements. Is the proposal better than Echo today?", "proposal",
                       "It still says which statement runs, without tinting the text you are reading."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "A bracket in the gutter, a grey arrow that lights on hover.",
                  values: ["statement": LabQEStatementLook.bracket.rawValue, "runArrow": LabQERunArrow.symbol.rawValue], isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["statement": LabQEStatementLook.band.rawValue, "runArrow": LabQERunArrow.triangle.rawValue]),
            .init(id: "quiet", name: "Quietest", summary: "Nothing until you point at the gutter.",
                  values: ["statement": LabQEStatementLook.hoverBand.rawValue, "runArrow": LabQERunArrow.hover.rawValue]),
        ]
    )
}
