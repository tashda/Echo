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
            .of("errorWord", "The wrong word", LabQEErrorWord.self, default: .glow,
                question: "Look at custmers on line 4 in each choice of the gallery, then switch to After a failed run. How should the wrong word be marked?",
                recommend: .glow,
                why: "You chose the glowing frame and asked for more of it, so I recommend it, with its look picked under Glow (rev 2). My first recommendation was the squiggle, the mark Echo draws for server errors; today's glow lost because it moves all the time and blurs the letters, which the still glows fix.",
                summary: \.summary, newChoices: (3, LabQEErrorWord.addedInRev3)),
            .of("errorMessage", "The message", LabQEErrorMessage.self, default: .hover,
                question: "Point at custmers in the Proposal, and imagine typing on line 4. Where should the message be?",
                recommend: .hover,
                why: "A message that appears 0.8 s after every pause while you are mid-word is noise; the bubble is what Echo already shows for server errors, and it appears the moment you go to fix the line. The pill and the banner are fine for a finished script, but they push past the edge on long lines and stack up with several mistakes.",
                summary: \.summary),
            .of("errorGlow", "Glow", LabQEErrorGlow.self, default: .hairlineHalo,
                question: "Look at the Glows gallery, in light and dark, then at the Proposal. Which glow should the wrong word get? All of them are still, as you chose (MO0).",
                recommend: .hairlineHalo,
                why: "You picked GW2, and among the new ones it is still the one I would ship: a crisp 1pt line says exactly which letters are wrong and the halo gives it the glow you like, without blurring the letters. Of rev 3's, the double ring (GW8) and the glow with a squiggle (GW9) come closest; the aura and the shadow are beautiful but vague about where the word ends.",
                summary: \.summary, addedIn: 2, newChoices: (3, LabQEErrorGlow.addedInRev3)),
            .of("errorBubble", "Bubble", LabQEErrorBubbleLook.self, default: .card,
                question: "Set The editor shows to A mistake, caret on its line (or point at custmers), then look at the Bubbles gallery. How should the bubble with the message look?",
                recommend: .card,
                why: "A title says what kind of mistake it is at a glance, the message reads in the text colour instead of all-red, and Fix sits where the hand goes: the hierarchy today's popover lacks. The glass bubble is the most macOS 26, but glass over code blurs the line it explains; the red-edge card is the close runner-up; the HUD is loud in light mode; the margin note is lovely but far from the word on wide windows.",
                summary: \.summary, addedIn: 3),
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
            LabQERound.gallery("Marks", "Every way of marking the wrong word, on the proposal (rev 3: nine without a glow).", LabQEErrorWord.self, \.errorWord,
                               scene: .liveError, cellHeight: 120),
            LabQERound.gallery("Glows", "Every glow round custmers, all still except today's.", LabQEErrorGlow.self, \.errorGlow,
                               scene: .liveError, id: "glowGallery", addedIn: 2, cellHeight: 120) { $0.errorWord = .glow },
            LabQERound.gallery("Bubbles", "Every bubble, with the caret on custmers's line.", LabQEErrorBubbleLook.self, \.errorBubble,
                               scene: .liveErrorCaret, id: "bubbleGallery", addedIn: 3, cellHeight: 190) { $0.errorMessage = .hover },
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
            .init(id: "recommended", name: "My recommendation", summary: "Your glow as a hairline with a halo, the message in the bubble, a dot by the number.",
                  values: ["errorWord": LabQEErrorWord.glow.rawValue, "errorGlow": LabQEErrorGlow.hairlineHalo.rawValue, "errorMessage": LabQEErrorMessage.hover.rawValue,
                           "errorBubble": LabQEErrorBubbleLook.card.rawValue, "errorDot": LabQEErrorDot.dot.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["errorWord": LabQEErrorWord.glow.rawValue, "errorMessage": LabQEErrorMessage.pill.rawValue, "errorDot": LabQEErrorDot.dot.rawValue]),
            .init(id: "xcode", name: "Like Xcode", summary: "Squiggle and a banner to the edge.",
                  values: ["errorWord": LabQEErrorWord.squiggle.rawValue, "errorMessage": LabQEErrorMessage.banner.rawValue, "errorDot": LabQEErrorDot.dot.rawValue]),
        ]
    )
}
