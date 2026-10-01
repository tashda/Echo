import SwiftUI

/// Round 43.3 · Settings: controls and words. Echo today (PropertyRow): every setting is a grouped
/// form row; a grey sentence under many titles (the gutter's is 23 words), ⓘ on some; toggles are
/// switches; sizes are pop-up menus; there is no way to return one setting to its default.
@MainActor
enum SettingsControlsRound {
    static let spec = RoundSpec(
        controls: [
            .of("descriptions", "Descriptions", LabSTLook.Descriptions.self, default: .short,
                question: "Compare the rows' descriptions. Which reads cleanest while staying clear?",
                recommend: .short,
                why: "System Settings writes a line only where the title can't say it; longer explanations go behind ⓘ. A sentence under every row makes the page twice as long and hides the titles in grey."),
            .of("reset", "Back to default", LabSTLook.Reset.self, default: .perRow,
                question: "Change the font size and the gutter style. Should a changed setting offer a way back?",
                recommend: .perRow,
                why: "A ↺ only on changed settings doubles as 'what have I changed?', and returns one setting without a Reset All that undoes everything."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Sentences under rows, no way back.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 560) { _ in
                LabSTWindow(look: LabSTLook(placement: .pinned, choices: .pictures, descriptions: .under, feedback: .ring, reset: .none))
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls, on 43.1 and 43.2's recommendations.", isWide: true, designWidth: 860, designHeight: 560) { values in
                LabSTWindow(look: LabSTLook.from(values))
            },
        ],
        questions: [
            .init(id: "toggles", title: "On and off",
                  question: "Switches or checkboxes for on/off settings?",
                  choices: [.init(id: "switch", name: "TG0 · Switches (today, as System Settings)"), .init(id: "check", name: "TG1 · Checkboxes, as older Mac apps")],
                  recommended: "switch",
                  why: "macOS 26's own Settings uses switches in grouped forms; Echo's settings already look like System Settings."),
            .init(id: "numbers", title: "Numbers",
                  question: "Sizes and amounts (font size, row limit, timeouts): which control?",
                  choices: [.init(id: "stepper", name: "NU0 · A stepper with its unit (13 pt), typing allowed"), .init(id: "menu", name: "NU1 · A pop-up of fixed values (today)"),
                            .init(id: "slider", name: "NU2 · A slider with ticks")],
                  recommended: "stepper",
                  why: "A stepper shows the exact value with its unit and goes one step at a time while the preview follows; a menu hides the neighbours and a slider can't hit 13 exactly."),
            .init(id: "sections", title: "Section names",
                  question: "Sections named by when they matter (While Typing, After a Run) or by what they change (Gutter, Marks)?",
                  choices: [.init(id: "what", name: "SN0 · By what they change, everywhere"), .init(id: "mixed", name: "SN1 · Mixed, as today")],
                  recommended: "what",
                  why: "Searching a page for 'the setting for the arrow beside a statement' is easier when sections name things you see; While Typing becomes Statement and Caret."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["descriptions": LabSTLook.Descriptions.short.rawValue, "reset": LabSTLook.Reset.perRow.rawValue], isRecommended: true)]
    )
}
