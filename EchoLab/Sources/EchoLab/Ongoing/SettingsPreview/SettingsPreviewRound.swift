import SwiftUI

/// Round 43.1 · Settings: the page and its preview. Echo today (EditorSettingsView, round 28.11):
/// Text, then EditorFontPreview (three lines in the chosen font, size and line height; it shows
/// nothing else), then Gutter, While Typing, Marks, After a Run and Edges. Scrolling down, the
/// preview leaves the screen, so changing the gutter or the marks shows nothing. The owner wants
/// Editor settings to become the template for every settings page.
@MainActor
enum SettingsPreviewRound {
    static let spec = RoundSpec(
        controls: [
            .of("placement", "Preview", LabSTLook.Placement.self, default: .pinned,
                question: "Change the gutter style, the marks and Wrap Long Lines in each exhibit. Where should the preview be so every change shows?",
                recommend: .pinned,
                why: "One live editor pinned above the settings shows every change wherever you've scrolled, in Settings' normal width. Per-section previews repeat the same editor four times; beside the settings needs a window twice as wide, which Settings windows aren't (System Settings is 715pt)."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Only the font shows in the preview; change Style or Corners and nothing visible happens.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 560) { _ in
                LabSTWindow(look: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the control, with 43.2 and 43.3's recommendations. Change any setting.",
                  isWide: true, designWidth: 860, designHeight: 560) { values in
                LabSTWindow(look: LabSTLook.from(values))
            },
        ],
        questions: [
            .init(id: "what", title: "What the preview shows",
                  question: "Should the preview be a real editor that follows every setting on the page (gutter, marks, the statement, errors, wrapping, edges)?",
                  choices: [.init(id: "all", name: "PS0 · Yes: every setting on the page shows in it"), .init(id: "font", name: "PS1 · Only the text (today)")],
                  recommended: "all",
                  why: "That's your rule: everything that changes something gets a preview. One editor that shows all of it is the simplest way to keep that promise as settings are added."),
            .init(id: "noVisual", title: "Pages with nothing to show",
                  question: "Some pages change nothing you can see (Databases' timeouts, Application Cache). What do they get?",
                  choices: [.init(id: "none", name: "PN0 · No preview: the page starts with its settings"), .init(id: "summary", name: "PN1 · A summary card of the current values")],
                  recommended: "none",
                  why: "A preview that can't change is decoration; the template's rule is 'a preview where settings change how something looks'."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["placement": LabSTLook.Placement.pinned.rawValue], isRecommended: true)]
    )
}
