import SwiftUI

/// Round 43.2 · Settings: a picture for every choice. Echo today: the gutter style is a segmented
/// control of four words with a sentence explaining them; mark corners is a pop-up menu and strength a
/// segmented control. Nothing points at what a change did.
@MainActor
enum SettingsPicturesRound {
    static let spec = RoundSpec(
        controls: [
            .of("choices", "Choices", LabSTLook.Choices.self, default: .pictures,
                question: "Compare Style, Corners and Strength in each exhibit. Which lets you choose without reading?",
                recommend: .pictures,
                why: "Like System Settings' Appearance and Dock pickers: a small picture of each choice beats a sentence describing four words, and it replaces the gutter's long subtitle. Pointing to preview (CH2) is subtle and needs a pointer over each option to learn anything."),
            .of("feedback", "After a change", LabSTLook.Feedback.self, default: .ring,
                question: "Change a setting in the Proposal. Should the preview point at what changed?",
                recommend: .ring,
                why: "Some changes are small (corners going from 3pt to round); a ring for a moment around the part that changed answers 'where did that go?'."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Words, a sentence, nothing points at the change.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 560) { _ in
                LabSTWindow(look: LabSTLook(placement: .pinned, choices: .words, descriptions: .under, feedback: .none, reset: .none))
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls, on 43.1's pinned preview.", isWide: true, designWidth: 860, designHeight: 560) { values in
                LabSTWindow(look: LabSTLook.from(values))
            },
        ],
        questions: [
            .init(id: "when", title: "When to use pictures",
                  question: "Pictures for every choice, or only where the options look different?",
                  choices: [.init(id: "visual", name: "PC0 · Only for choices that change a look (gutter, corners, density, icons)"), .init(id: "all", name: "PC1 · Every choice")],
                  recommended: "visual",
                  why: "A picture of 'Every 5 seconds' or 'SQL Server 2019' says nothing a word doesn't."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["choices": LabSTLook.Choices.pictures.rawValue, "feedback": LabSTLook.Feedback.ring.rawValue], isRecommended: true)]
    )
}
