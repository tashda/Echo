import SwiftUI

/// Round 28.5 · Editor: highlights and marks. Everything drawn on the text itself, so it shares
/// one shape. Echo today (SQLTextView+Highlighting): the other uses of the word at the caret get
/// the selection colour at 30% as a text background, square and the whole 31pt line high; find
/// uses the native find bar and yellow indicator; there is no bracket matching.
@MainActor
enum EditorMarksRound {
    static let spec = RoundSpec(
        controls: [
            .of("wordHighlight", "The word at the caret", LabQEWordHighlight.self, default: .soft,
                question: "The caret is in shipped_at on line 5; look at line 12. How should the word's other uses be marked?",
                recommend: .soft,
                why: "A grey tint as high as the letters finds the other uses without looking like a selection; today's blue at full line height reads as a second, broken selection. An underline is quieter but clashes with the error squiggle and with links.",
                summary: \.summary),
            .of("markCorner", "Corner of a mark", LabQEMarkCorner.self, default: .followSelection,
                question: "With the soft tint, try each corner (new: 2, 4 and 6pt, and following the selection's setting). Which radius should every mark on the text use?",
                recommend: .followSelection,
                why: "You made the selection's corners a setting (3pt by default); marks that follow it always match the selection, whatever you set, and 3pt is also the find indicator's rounding. A fixed radius would drift from the selection the day you change the setting; 0 looks like a selection, 5 and 6pt turn short words into pills.",
                summary: \.summary, newChoices: (2, [.c2, .c4, .c6, .followSelection])),
            .of("findPreview", "Find matches (preview)", LabQEFindPreview.self, default: .native, addedIn: 2),
            .of("markHeight", "Height of a mark", LabQEMarkHeight.self, default: .letters,
                question: "Compare a mark as high as the line with one as high as the letters. Which should every mark use?",
                recommend: .letters,
                why: "Marks as high as the letters leave the gap between lines open, so marks on neighbouring lines never touch; that is how Xcode and the find indicator draw them. Full-line marks only make sense for the selection, which must join line to line."),
            LabQERound.sceneControl(default: .typing),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("shipped_at on lines 5 and 12 in the selection blue at 30%, the whole line high.", scene: .typing, before28: true),
            LabQERound.proposal("Built from the controls; try Finding “orders” too.", scene: .typing),
            LabQERound.gallery("Word highlights", "Every way of marking the word's other uses, on the proposal.", LabQEWordHighlight.self, \.wordHighlight, scene: .typing),
            LabQERound.gallery("Find matches", "Every way of marking find matches, finding “orders” (lines 3 and 10; the first is the current one).", LabQEFindPreview.self, \.findPreview,
                               scene: .find, id: "findGallery", addedIn: 2),
        ],
        questions: [
            .init(id: "find", title: "Find",
                  question: "Look at the Find matches gallery (or set The editor shows to Finding “orders” and switch Find matches). How should matches look? The find bar itself is page 28.12.",
                  choices: LabQEFindLook.allCases.map { look in
                      .init(id: look.rawValue, name: look.title, summary: look.summary, addedIn: [.native, .echo].contains(look) ? nil : 2)
                  },
                  recommended: "native",
                  why: "The dimmed text with lit matches and the yellow bubble is what every Mac app shows while you find, and NSTextView gives it for free. Echo's grey tint (F1) is the word-at-the-caret highlight, so a search and a highlighted word would look the same; the yellow tint (F2) is the best of the drawn ones if you want nothing to dim."),
            .init(id: "brackets", title: "Matching brackets",
                  question: "The caret is next to a ( or ). Should Echo show its partner? (Not in the specimen: the sample has no brackets.)",
                  choices: [
                      .init(id: "off", name: "P0 · No (today)"),
                      .init(id: "flash", name: "P1 · A short flash on the partner as you type the closing one", summary: "What NSTextView and Xcode do."),
                      .init(id: "stay", name: "P2 · Both stay marked while the caret is beside one"),
                  ],
                  recommended: "flash",
                  why: "Nested function calls and IN (…) lists are where SQL goes wrong; a flash as you close one tells you what you closed without leaving marks behind. A mark that stays adds a third tint next to the word highlight."),
            .init(id: "glass", title: "Glass on the text",
                  question: "Should anything drawn on the text itself (marks, notes, bubbles) use Liquid Glass?",
                  choices: [
                      .init(id: "no", name: "GL0 · No: glass only on controls"),
                      .init(id: "notes", name: "GL1 · Glass for notes and bubbles that float over code"),
                  ],
                  recommended: "no",
                  why: "You decided glass is for controls, never for content (rounds 3 to 8). Glass over text also blurs the code underneath, which is the one thing it must not do. Controls that float over the editor, like the zoom pill, are controls and keep glass."),
            .init(id: "delay", title: "How soon the word lights up",
                  question: "Today the word's other uses light up 0.25 s after the caret stops. Is that right?",
                  choices: [
                      .init(id: "today", name: "D0 · 0.25 s (today)"),
                      .init(id: "slower", name: "D1 · 0.5 s", summary: "Fewer flickers while you arrow through a line."),
                  ],
                  recommended: "today",
                  why: "Xcode waits about as long; at 0.5 s it feels broken when you stop on a word to check it."),
        ],
        exhibitTopic: ("Which marks?", "Compare the word highlight and a find in both. Is the proposal better than Echo today?", "proposal",
                       "Every mark on the text has one shape (3pt corners, as high as the letters), so marks never touch and none looks like a selection."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Soft tint, corners that follow the selection's setting, as high as the letters.",
                  values: ["wordHighlight": LabQEWordHighlight.soft.rawValue, "markCorner": LabQEMarkCorner.followSelection.rawValue, "markHeight": LabQEMarkHeight.letters.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["wordHighlight": LabQEWordHighlight.today.rawValue, "markCorner": LabQEMarkCorner.c0.rawValue, "markHeight": LabQEMarkHeight.line.rawValue]),
        ]
    )
}
