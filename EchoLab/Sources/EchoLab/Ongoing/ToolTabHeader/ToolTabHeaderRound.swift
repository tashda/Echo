import SwiftUI

/// Round 37.2 · Tool tabs: the header and toolbar row (changes TLT-1.5 and TLT-2.1). Echo today:
/// TT2's header (28pt tinted tile, 13pt title, 11pt subtitle), then `TabSectionToolbar` with
/// whatever each tool puts in it. SQL Profiler's (ProfilerView): a bordered small tinted "Start
/// Trace", a borderless trash, "Database" and a pop-up, borderless Events and Export symbols, and a
/// green "Tracing" at the right; the owner finds it off against the rest of Echo.
@MainActor
enum ToolTabHeaderRound {
    static let spec = RoundSpec(
        controls: [
            .of("header", "Layout", LabTTHeaderStyle.self, default: .twoRows,
                question: "Compare the layouts on the three tools. Which reads clearly with pages, a picker and actions at once?",
                recommend: .twoRows,
                why: "The name line answers what and where (and holds the one main action, as the editor's Run does); the second line is how you look at it. One row runs out of room as soon as a tool has pages; the glass bar (UH3) is the close second and the one to pick if you want tools to feel like the editor's floating pieces.",
                summary: \.summary),
            .of("running", "Running", LabTTRunning.self, default: .running),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today: SQL Profiler", summary: "As built, tracing.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .profiler, look: .today, running: (LabTTRunning(rawValue: values["running"]) ?? .running) == .running)
            },
            .init(id: "profiler", title: "Proposal: SQL Profiler", summary: "Built from the controls, with 37.3's recommended controls.",
                  isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .profiler, look: look(values), running: (LabTTRunning(rawValue: values["running"]) ?? .running) == .running)
            },
            .init(id: "policy", title: "Proposal: Policy Management", summary: "Pages, a primary action and search.",
                  isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .policy, look: look(values))
            },
            .init(id: "activity", title: "Proposal: Activity Monitor", summary: "Pages, an interval picker and Pause.",
                  isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .activity, look: look(values))
            },
        ],
        questions: [
            .init(id: "pagesPlace", title: "Pages",
                  question: "If round 36 puts a tool's pages in its tab, the toolbar row has no pages. Is that what you want?",
                  choices: [
                      .init(id: "tab", name: "PG0 · Yes: pages in the tab (36.1), the row has filters, search and actions"),
                      .init(id: "row", name: "PG1 · No: pages lead the toolbar row; the tab stays plain"),
                  ],
                  recommended: "tab",
                  why: "Follows 36.1's recommendation; the exhibits keep the pages in the row only so you can judge both."),
        ],
        exhibitTopic: ("Which header?", "Which of these is the header for every tool?", "profiler",
                       "Two rows: name, subtitle and the main action, then the ways of looking at the data and the other actions, all in glass."),
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["header": LabTTHeaderStyle.twoRows.rawValue], isRecommended: true),
            .init(id: "glass", name: "Editor's language", values: ["header": LabTTHeaderStyle.glassBar.rawValue]),
        ]
    )

    private static func look(_ values: RoundValues) -> LabTTLook {
        var look = LabTTLook()
        look.header = LabTTHeaderStyle(rawValue: values["header"]) ?? .twoRows
        return look
    }
}

/// Playground: the trace running or stopped.
enum LabTTRunning: String, CaseIterable {
    case running = "Tracing"
    case stopped = "Stopped"
}
