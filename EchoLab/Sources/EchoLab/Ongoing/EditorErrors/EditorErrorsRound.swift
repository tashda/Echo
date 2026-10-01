import SwiftUI

/// Round 28.6 · Editor: errors in the text. Echo today has two looks for “this is wrong”:
/// a mistake found while typing (live validation, 0.8 s after you stop) is a glowing frame of
/// three blurred red gradient strokes that keep shifting, plus a pink pill with an icon and the
/// message at the line's end (ValidationAccessoryView, ValidationInlineAnnotation); the server's
/// error after a run is a red squiggle with the message in a bubble on hover and “! Error” as the
/// run note (round 21 EM5, round 22 ED1). Both put a red dot by the line number. Changes EDT-2.3.
@MainActor
enum EditorErrorsRound {
    static let spec = RoundSpec(
        controls: [
            .of("errorWord", "The wrong word", LabQEErrorWord.self, default: .squiggle,
                question: "Look at custmers on line 4 in each choice of the gallery, then switch to After a failed run. How should the wrong word be marked?",
                recommend: .squiggle,
                why: "Echo already draws the squiggle for the server's errors (accepted in round 21), and it is what every Mac app uses for a mistake in text, so one mark covers both. The glow moves all the time while you are still typing, blurs the letters it is meant to point at, and looks like EchoSense's glow; the tint looks like a highlight; the dotted line means spelling.",
                summary: \.summary),
            .of("errorMessage", "The message", LabQEErrorMessage.self, default: .hover,
                question: "Point at custmers in the Proposal, and imagine typing on line 4. Where should the message be?",
                recommend: .hover,
                why: "A message that appears 0.8 s after every pause while you are mid-word is noise; the bubble is what Echo already shows for server errors, and it appears the moment you go to fix the line. The pill and the banner are fine for a finished script, but they push past the edge on long lines and stack up with several mistakes.",
                summary: \.summary),
            .of("errorDot", "In the gutter", LabQEErrorDot.self, default: .dot,
                question: "Look at the gutter beside line 4. How should the gutter mark the line?",
                recommend: .dot,
                why: "The dot is how you find an error that is scrolled sideways or hidden in a long line, and it is what the outline edge echoes. A red number reads as a different kind of number; nothing leaves you to find a 1pt squiggle in a 200-line script."),
            LabQERound.sceneControl(default: .liveError),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("While typing: the glowing frame and the pill. After a failed run: the squiggle, the bubble on hover and “! Error”.", scene: .liveError),
            LabQERound.proposal("Built from the controls, the same while typing and after a run. Point at the word.", scene: .liveError),
            LabQERound.gallery("Marks", "Every way of marking the wrong word, on the proposal.", LabQEErrorWord.self, \.errorWord, scene: .liveError),
        ],
        questions: [
            .init(id: "sameLook", title: "While typing and after a run",
                  question: "EchoSense finds custmers while you type; the server finds it again when you run. Should the two look the same?",
                  choices: [
                      .init(id: "same", name: "SL0 · The same mark and bubble"),
                      .init(id: "lighter", name: "SL1 · Typing in orange, the server's in red", summary: "Says “probably wrong” against “the server said so”."),
                  ],
                  recommended: "same",
                  why: "What EchoSense flags (an unknown table, column or schema, a syntax error) is wrong for the server too, so a second colour only asks you to learn a difference that doesn't matter. The bubble's second line can still say where it came from."),
            .init(id: "timing", title: "When it appears",
                  question: "Today the check runs 0.8 s after you stop typing. When should the mark appear?",
                  choices: [
                      .init(id: "today", name: "T0 · 0.8 s after you stop (today)"),
                      .init(id: "leave", name: "T1 · When you leave the line or stop for 2 s"),
                  ],
                  recommended: "leave",
                  why: "Half-typed names are always “unknown” for a moment; waiting until you move on or really stop means the squiggle only appears for real mistakes. Xcode works the same way for its live issues."),
            .init(id: "motion", title: "Movement",
                  question: "Should an error mark move (pulse, shimmer) to get attention?",
                  choices: [
                      .init(id: "still", name: "MO0 · Still"),
                      .init(id: "pulse", name: "MO1 · A single pulse when it appears"),
                  ],
                  recommended: "still",
                  why: "Today's glow never stops moving, which is the main reason it feels loud. Your motion rule is that motion shows a change; an error that appears while you type is a change you caused, so it doesn't need announcing."),
            .init(id: "showMessage", title: "Run note for an error",
                  question: "After a failed run the note says “! Error” and the bubble has the message (RN1, accepted in round 21; Settings can show the whole message). Keep it?",
                  choices: [
                      .init(id: "short", name: "EN0 · ! Error (today, RN1)"),
                      .init(id: "message", name: "EN1 · The message, cut to 80 characters"),
                  ],
                  recommended: "short",
                  why: "You accepted RN1 in round 21; with the bubble on the word, the message would be on screen twice."),
        ],
        exhibitTopic: ("Which error marks?", "Switch between A mistake while typing and After a failed run in both. Is the proposal better than Echo today?", "proposal",
                       "One quiet mark for every error, the message when you go to fix it, and the dot to find it."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Squiggle, the message in the bubble, a dot by the number.",
                  values: ["errorWord": LabQEErrorWord.squiggle.rawValue, "errorMessage": LabQEErrorMessage.hover.rawValue, "errorDot": LabQEErrorDot.dot.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["errorWord": LabQEErrorWord.glow.rawValue, "errorMessage": LabQEErrorMessage.pill.rawValue, "errorDot": LabQEErrorDot.dot.rawValue]),
            .init(id: "xcode", name: "Like Xcode", summary: "Squiggle and a banner to the edge.",
                  values: ["errorWord": LabQEErrorWord.squiggle.rawValue, "errorMessage": LabQEErrorMessage.banner.rawValue, "errorDot": LabQEErrorDot.dot.rawValue]),
        ]
    )
}
