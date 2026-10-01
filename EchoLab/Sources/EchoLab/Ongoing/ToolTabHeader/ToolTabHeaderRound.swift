import SwiftUI

/// Round 37.2 · Tool tabs: the header and toolbar row (changes TLT-1.5 and TLT-2.1). Echo today:
/// TT2's header (28pt tinted tile, 13pt title, 11pt subtitle), then `TabSectionToolbar` with
/// whatever each tool puts in it. SQL Profiler's (ProfilerView): a bordered small tinted "Start
/// Trace", a borderless trash, "Database" and a pop-up, borderless Events and Export symbols, and a
/// green "Tracing" at the right; the owner finds it off against the rest of Echo.
/// Revision 2: the owner wants the pages in the tab (confirmed: the tab bar, 36.1) and everything
/// else on one line where the header is. Added UH5 to UH8, drawn under the strip with TP5.
@MainActor
enum ToolTabHeaderRound {
    static let spec = RoundSpec(
        controls: [
            .of("header", "Layout", LabTTHeaderStyle.self, default: .oneLine,
                question: "With the pages in the tab, compare UH5 to UH8 on the three tools. Which one line reads clearly with a picker, search and actions?",
                recommend: .oneLine,
                why: "UH5 keeps the header you decided in TT2 (tinted tile, name, subtitle) and only moves the controls up beside it, so every tool loses the 40pt second row and nothing else changes. UH8 is the leanest, but a tool without pages (SQL Profiler) would then have no name inside the tab; UH7 is the pick if you want the editor's floating glass.",
                summary: \.summary, newChoices: (2, LabTTHeaderStyle.revision2)),
            .of("running", "Running", LabTTRunning.self, default: .running),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today: SQL Profiler", summary: "As built, tracing.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 330) { values in
                LabTTTab(tool: .profiler, look: .today, running: (LabTTRunning(rawValue: values["running"]) ?? .running) == .running)
            },
            .init(id: "profiler", title: "Proposal: SQL Profiler", summary: "Built from the controls, with 37.3's accepted controls; UH5 to UH8 show the tab above.",
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
            .init(id: "oneLines", title: "The four one-line headers", summary: "UH5 to UH8 on Policy Management, under its tab (TP5).",
                  isWide: true, addedIn: 2, designWidth: 860, designHeight: 340) { _ in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    LabTPStrip(tabs: [.query2, .policy], activeID: LabTPTab.policy.id, style: .group)
                    ForEach(LabTTHeaderStyle.revision2, id: \.self) { style in
                        Text(style.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        LabTTHeaderView(tool: .policy, look: { var look = LabTTLook(); look.header = style; return look }())
                    }
                }
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
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
                  why: "You told me the pages belong in the tab bar; UH5 to UH8 are drawn that way, with TP5's strip above them."),
        ],
        exhibitTopic: ("Which header?", "Which of these is the header for every tool?", "profiler",
                       "One line under the tab (UH5): tile, name and subtitle, then the controls in glass; the pages are in the tab."),
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["header": LabTTHeaderStyle.oneLine.rawValue], isRecommended: true),
            .init(id: "twoRows", name: "Two rows (rev 1)", values: ["header": LabTTHeaderStyle.twoRows.rawValue]),
            .init(id: "glass", name: "Editor's language", values: ["header": LabTTHeaderStyle.glassBar.rawValue]),
        ]
    )

    private static func look(_ values: RoundValues) -> LabTTLook {
        var look = LabTTLook()
        look.header = LabTTHeaderStyle(rawValue: values["header"]) ?? .oneLine
        return look
    }
}

/// Playground: the trace running or stopped.
enum LabTTRunning: String, CaseIterable {
    case running = "Tracing"
    case stopped = "Stopped"
}
