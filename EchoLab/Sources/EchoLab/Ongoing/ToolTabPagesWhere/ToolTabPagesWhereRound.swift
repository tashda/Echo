import SwiftUI

/// Round 36.2 · Tool tabs with pages: which tools. Echo today: only Activity Monitor has pages in
/// its tab (WorkspaceTab+ToolPages). Nine tools switch sections with a segmented control inside the
/// tab (TabSectionPicker): Maintenance (5 on SQL Server, 3 on PostgreSQL), Server Properties (6),
/// Database Security (9 on SQL Server, 3 on PostgreSQL), Server Security (4), Policy Management (4),
/// Advanced Objects (4), Tuning Advisor (2), Error Log (2), Query Store (2).
@MainActor
enum ToolTabPagesWhereRound {
    enum Which: String, CaseIterable {
        case today = "WP0 · Only Activity Monitor (today)"
        case views = "WP1 · Every tool whose sections are separate views (all ten)"
        case threeOrMore = "WP2 · Tools with three or more sections; two-section tools keep a segmented control"
    }

    enum Overflow: String, CaseIterable {
        case scroll = "OF0 · The pages scroll sideways (today)"
        case more = "OF1 · The pages that don't fit go into a More menu at the end"
        case shorten = "OF2 · Only the shown page's name; the others as symbols"
    }

    static let spec = RoundSpec(
        controls: [
            .of("which", "Which tools", Which.self, default: .views,
                question: "Look at the tools in the gallery. Which should have their pages in the tab?",
                recommend: .views,
                why: "One rule for every tool is easier to learn than a count to remember: if a tool's sections are separate screens (Policy Management's Policies and History are), they are pages. Two pages in the tab still save the 40pt row the segmented control takes inside it."),
            .of("overflow", "Too many pages", Overflow.self, default: .more,
                question: "Database Security has nine pages. With three other tabs open, how should the ones that don't fit behave?",
                recommend: .more,
                why: "Sideways scrolling hides pages without telling you they exist; a More menu at the end is what the toolbar and Safari's tab bar do. Symbols need nine icons that mean Masking and RLS, which nobody reads at a glance."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Policy Management: a normal tab, its sections in a segmented control inside.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 200) { _ in
                LabTPExhibit(style: .inTab, single: .fill, alone: false, tool: .policy)
            },
            .init(id: "gallery", title: "Tools with pages", summary: "Five tools as they'd look with the proposal from 36.1 (TP2).",
                  isWide: true, designWidth: 860, designHeight: 380) { values in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach([LabTPTab.policy, .maintenance, .serverProperties, .dbSecurity, .activityMonitor]) { tool in
                        LabTPStrip(tabs: [.query2, .jobs, overflowed(tool, Overflow(rawValue: values["overflow"]) ?? .more)], activeID: tool.id, style: .segments)
                    }
                }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
            },
        ],
        questions: [
            .init(id: "remember", title: "Remembering the page",
                  question: "You close Policy Management on History and open it again. Which page?",
                  choices: [
                      .init(id: "last", name: "RM0 · History, the last page you used on this server"),
                      .init(id: "first", name: "RM1 · Always the first page"),
                  ],
                  recommended: "last",
                  why: "You reopen a tool to continue; the dock already remembers each server's section the same way."),
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["which": Which.views.rawValue, "overflow": Overflow.more.rawValue], isRecommended: true),
        ]
    )

    /// A tool with more than six pages ends with More (OF1) or keeps all of them.
    private static func overflowed(_ tool: LabTPTab, _ overflow: Overflow) -> LabTPTab {
        guard tool.pages.count > 6, overflow == .more else { return tool }
        var copy = tool
        copy.pages = Array(tool.pages.prefix(5)) + ["More ⌄"]
        return copy
    }
}
