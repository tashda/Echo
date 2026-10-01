import SwiftUI

/// Round 28.15 · Editor: one design language (the owner's note on 28.13: the replacement, the
/// error and everything else in the editor should share colours, pills and corners, from tokens
/// and configurable in Settings). Echo today mixes them: the mistake is a red 14% capsule
/// (ErrorPillView), the word at the caret a 9% grey with Highlight Corners (3pt), the selection
/// the system's colour with Selection Corners (3pt), find the system's yellow bubble, the
/// statement a 70% accent bracket; floating pieces (run note, bubble, zoom, find bar) are glass.
@MainActor
enum EditorDesignLanguageRound {
    static let spec = RoundSpec(
        controls: [
            .of("dlCorner", "Corners", LabQEDLCorner.self, default: .oneCorner,
                question: "Compare the two samplers, row by row. Should every mark share one corner?",
                recommend: .oneCorner,
                why: "One corner from Settings makes the mistake, the word, find and the replacement read as one family; today the mistake is the only capsule, so it looks like a different kind of thing. 3pt is the system find indicator's own rounding. Round ends on every mark turn short words into beads.",
                summary: nil),
            .of("dlTint", "Tints", LabQEDLTint.self, default: .twoSteps,
                question: "Should marks share a few strengths instead of each picking its own?",
                recommend: .twoSteps,
                why: "Two steps say enough: soft (10%) for “also here” (the word's other uses, other matches, what will be added), strong (22%) for “this one” (the current match, a mistake, what will be removed). Today there are six different strengths that mean nothing to the eye. Three steps are finer than anyone reads."),
            .of("dlColour", "Colours", LabQEDLColour.self, default: .meaning,
                question: "Should each colour mean one thing everywhere in the editor?",
                recommend: .meaning,
                why: "Grey same word, yellow found, red wrong or removed, green added or done, accent where you are: the same meanings the footer, the toast and the run note already use, so nothing new to learn. All accent would make a find match and the statement look alike.",
                summary: \.summary),
            .of("dlHeight", "Height", LabQEDLHeight.self, default: .letters,
                question: "As high as the letters, or the whole line?",
                recommend: .letters,
                why: "You chose the letters' height for marks (28.5); it keeps marks on neighbouring lines apart. The selection keeps the whole line so a multi-line selection stays joined."),
            .of("dlSettings", "Settings", LabQEDLSettings.self, default: .marks,
                question: "What should Settings let you change about marks?",
                recommend: .marks,
                why: "You asked for marks to be configurable: one Marks section with Corners and Strength covers every mark (and the selection) in two controls, instead of today's two corner settings that the mistake and find ignore. Strength helps people on bright screens or with low vision.",
                summary: \.summary),
            .of("dlFloating", "Floating pieces", LabQEDLFloating.self, default: .glass,
                question: "Everything that floats over the code: one look?",
                recommend: .glass,
                why: "You chose glass for the run note (R10), the bubble (BB3), the zoom and the find bar (FB5); making them share the same capsule, 11pt type, coloured symbol and grey words makes them one family. Marks on the text never use glass (your GL0).",
                summary: \.summary),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Every mark as Echo draws it now (the replacement as 28.13's PV2).", isEchoToday: true,
                  designWidth: LabQEMarkSampler.width, designHeight: LabQEMarkSampler.height) { _ in
                LabQEMarkSampler(language: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Every mark in the language set by the controls.",
                  designWidth: LabQEMarkSampler.width, designHeight: LabQEMarkSampler.height) { values in
                LabQEMarkSampler(language: language(values))
            },
        ],
        questions: [
            .init(id: "tokens", title: "Where the language lives",
                  question: "Should the language be design tokens that every mark reads, so a new mark can't pick its own values?",
                  choices: [
                      .init(id: "tokens", name: "TK0 · Tokens: EditorMark (corner, soft, strong, colours by meaning, height)"),
                      .init(id: "each", name: "TK1 · Each mark keeps its own values"),
                  ],
                  recommended: "tokens",
                  why: "One place to change it and one place Settings writes to; the same rule the rest of Echo follows for colours and spacing."),
        ],
        exhibitTopic: ("Which language?", "Compare row by row and the Together lines. Is the proposal better than Echo today?", "proposal",
                       "Every mark the same shape and two strengths, coloured by meaning, from tokens you can tune in Settings › Editor › Marks."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "One 3pt corner, two strengths, colour by meaning, letters' height, a Marks section, glass for floating pieces.",
                  values: ["dlCorner": LabQEDLCorner.oneCorner.rawValue, "dlTint": LabQEDLTint.twoSteps.rawValue, "dlColour": LabQEDLColour.meaning.rawValue,
                           "dlHeight": LabQEDLHeight.letters.rawValue, "dlSettings": LabQEDLSettings.marks.rawValue, "dlFloating": LabQEDLFloating.glass.rawValue],
                  isRecommended: true),
            .init(id: "today", name: "Like Echo today",
                  values: ["dlCorner": LabQEDLCorner.mixed.rawValue, "dlTint": LabQEDLTint.mixed.rawValue, "dlColour": LabQEDLColour.mixed.rawValue,
                           "dlHeight": LabQEDLHeight.letters.rawValue, "dlSettings": LabQEDLSettings.today.rawValue, "dlFloating": LabQEDLFloating.glass.rawValue]),
            .init(id: "pills", name: "Pills", summary: "Round ends on every mark, three strengths.",
                  values: ["dlCorner": LabQEDLCorner.round.rawValue, "dlTint": LabQEDLTint.threeSteps.rawValue, "dlColour": LabQEDLColour.meaning.rawValue,
                           "dlHeight": LabQEDLHeight.letters.rawValue, "dlSettings": LabQEDLSettings.marks.rawValue, "dlFloating": LabQEDLFloating.glass.rawValue]),
        ]
    )

    static func language(_ values: RoundValues) -> LabQEMarkLanguage {
        LabQEMarkLanguage(corner: LabQEDLCorner(rawValue: values["dlCorner"]) ?? .oneCorner,
                          tint: LabQEDLTint(rawValue: values["dlTint"]) ?? .twoSteps,
                          colour: LabQEDLColour(rawValue: values["dlColour"]) ?? .meaning,
                          height: LabQEDLHeight(rawValue: values["dlHeight"]) ?? .letters,
                          floating: LabQEDLFloating(rawValue: values["dlFloating"]) ?? .glass)
    }
}
