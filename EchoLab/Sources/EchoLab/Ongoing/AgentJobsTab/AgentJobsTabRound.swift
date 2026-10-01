import SwiftUI

/// Round 33.1 · SQL Server Agent Jobs: the tab. Echo today (JobQueueView, JobListView, JobDetailsView,
/// JobHistoryView): three cards in two CardSplitViews, Jobs beside Details at 50%, History under
/// both at 30%. Jobs and History headers are `TypographyTokens.headline` with 12 by 6pt padding;
/// Details is `prominent` semibold with 16 by 12pt padding and its sections centred under it. The
/// lists stripe every second row and keep striping to the bottom. The owner likes the idea and
/// wants it finished; round 37 decides the shared design for all tool tabs, this is Agent Jobs itself.
/// Accepted 2026-10-01 (JH1, JL1, DT0, JC1, ER1, JA1, JR1) and built into Echo: the Proposal now
/// opens on the accepted picks.
@MainActor
enum AgentJobsTabRound {
    static let spec = RoundSpec(
        controls: [
            .of("headers", "Headers", LabAJHeaders.self, default: .unified,
                question: "Look along the tops of the three panes in Echo today and the Proposal. Should every pane have the same header?",
                recommend: .unified,
                why: "This is the 'headers sit in different places' you saw: Details is a point bigger and 4pt further in and down than the other two. One header (title, count, actions on one 36pt line) also gives New Job and Start a home instead of the ⋯ menu.",
                summary: \.summary),
            .of("layout", "Layout", LabAJLayout.self, default: .jobsFull,
                question: "Try the three layouts. Which gives the jobs list and the history the room they need?",
                recommend: .jobsFull,
                why: "It keeps your three cards, but the jobs list gets the whole height, so 24 jobs fit without scrolling, and History sits under the job it describes. JL2 hides history behind a click, which is the thing you open the tab to check after a failure.",
                summary: \.summary),
            .of("sections", "Details sections", LabAJSections.self, default: .today,
                question: "Where should Properties, Steps, Schedules and Notifications sit?",
                recommend: .header,
                why: "On the header's line they take no height of their own and line up with the other panes' actions; centred under the title they push the content down by 30pt and float away from everything else."),
            .of("columns", "Jobs columns", LabAJColumns.self, default: .compact,
                question: "Compare the jobs list's columns. Which tells you more at a glance?",
                recommend: .compact,
                why: "Owner and Category barely vary between jobs, while last and next run are what you check; one status symbol replaces the Enabled tick and the Status word, so names stop being cut at 14 characters.",
                summary: \.summary),
            .of("empty", "Empty rows", LabAJEmptyRows.self, default: .plain,
                question: "Look at the space under the last step and the last job.",
                recommend: .plain,
                why: "Stripes under the last row look like rows waiting to load (the Steps list shows 1 step and 8 empty stripes); a list should end where its rows end."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Three header styles, sections centred, stripes to the bottom.",
                  isEchoToday: true, isWide: true, designWidth: 760, designHeight: 460) { _ in
                LabAJTab(look: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  isWide: true, designWidth: 760, designHeight: 460) { values in
                LabAJTab(look: LabAJLook.from(values))
            },
        ],
        questions: [
            .init(id: "actions", title: "Job actions",
                  question: "Where do New Job, Start, Stop, Enable and Disable live?",
                  choices: [
                      .init(id: "menu", name: "JA0 · In the ⋯ menu and the right-click menu (today)"),
                      .init(id: "header", name: "JA1 · New Job and Start/Stop on the Jobs header; the rest in ⋯ and right-click"),
                      .init(id: "toolbar", name: "JA2 · In the window's toolbar while the tab is in front"),
                  ],
                  recommended: "header",
                  why: "The two things you do most get a button where you are looking; round 37 decides the same rule for every tool tab, so this follows it."),
            .init(id: "running", title: "A running job",
                  question: "How should a running job show in the list?",
                  choices: [
                      .init(id: "word", name: "JR0 · The word Running in orange (today)"),
                      .init(id: "time", name: "JR1 · A spinning symbol and its elapsed time in Last run"),
                  ],
                  recommended: "time",
                  why: "How long it has been running is what you want to know; the elapsed time answers it in the column you already read."),
        ],
        exhibitTopic: ("Finished?", "Does the Proposal feel like the finished version of the tab you like?", "proposal",
                       "Same three cards, one header for all, the list at full height, sections on the header line, useful columns, no ghost rows."),
        presets: [
            .init(id: "accepted", name: "Accepted", summary: "Unified headers, jobs full height, sections centred under the title, compact columns, plain.",
                  values: ["headers": LabAJHeaders.unified.rawValue, "layout": LabAJLayout.jobsFull.rawValue, "sections": LabAJSections.today.rawValue,
                           "columns": LabAJColumns.compact.rawValue, "empty": LabAJEmptyRows.plain.rawValue],
                  isRecommended: true),
        ]
    )
}
