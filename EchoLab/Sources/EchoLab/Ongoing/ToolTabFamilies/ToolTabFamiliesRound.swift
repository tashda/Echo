import SwiftUI

/// Round 37.1 · Tool tabs: the families. Echo has 25 tab kinds besides the query editor
/// (WorkspaceTab.Kind). Today they share TT2's header and TabSectionToolbar, but every tool picks its
/// own button styles, pickers and layout below it. This page sorts them into five families by the
/// shape of their work; 37.2 and 37.3 design what they share, 37.4 each family's theme.
@MainActor
enum ToolTabFamiliesRound {
    static let spec = RoundSpec(
        exhibits: [
            .init(id: "map", title: "Every tool tab, by family", summary: "What each family is for, and which tools are in it.",
                  isWide: true, designWidth: 900, designHeight: 460) { _ in
                LabTTFamilyMap()
            },
        ],
        questions: [
            .init(id: "families", title: "The families",
                  question: "Are these five families right, as the groups each theme is designed for?",
                  choices: [
                      .init(id: "yes", name: "FA0 · Yes: monitor, manage, health, properties, canvas"),
                      .init(id: "fewer", name: "FA1 · Fewer: fold health into manage"),
                      .init(id: "change", name: "FA2 · Something is in the wrong family (say which in the note)"),
                  ],
                  recommended: "yes",
                  why: "Each family has a different main action and layout: watching (pause, interval), editing a list (new, delete, details), fixing findings (run, fix), applying settings (apply, revert), and moving around a drawing (zoom, arrange). Folding health into manage loses its worst-first order and the Fix button."),
            .init(id: "queryStore", title: "Query Store",
                  question: "Query Store shows top and regressed queries over time. Monitor or health?",
                  choices: [.init(id: "monitor", name: "QS0 · Monitor (it charts history)"), .init(id: "health", name: "QS1 · Health (it finds regressions to fix)")],
                  recommended: "health",
                  why: "You open it to find a regressed plan and force the good one, which is a finding and a fix, not something you watch live."),
            .init(id: "psql", title: "psql console",
                  question: "The PostgreSQL psql console is a tab too. Does it follow the tool themes?",
                  choices: [.init(id: "editor", name: "PS0 · No: it follows the editor's design (round 28)"), .init(id: "monitor", name: "PS1 · Yes, as a monitor")],
                  recommended: "editor",
                  why: "It's a text surface you type into, so the editor's language (text, marks, the run note) fits it; a tool header would be a second chrome around a terminal."),
            .init(id: "unified", title: "One theme for all",
                  question: "What should every family share, whatever its theme?",
                  choices: [
                      .init(id: "header", name: "UT0 · The header, the toolbar row and the controls (37.2, 37.3)"),
                      .init(id: "headerPanes", name: "UT1 · UT0, plus pane cards, tables and empty states"),
                  ],
                  recommended: "headerPanes",
                  why: "The header is where tools differ most today, but the panes are where you spend your time: one table style and one empty state make them read as one app (round 32.1 already settles the stripes)."),
        ]
    )
}

/// Five columns, one per family.
private struct LabTTFamilyMap: View {
    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            ForEach(LabTTFamily.allCases, id: \.self) { family in
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Label(family.rawValue, systemImage: family.symbol).font(TypographyTokens.headline)
                    Text(family.summary).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    ForEach(family.tools, id: \.self) { tool in
                        Text(tool).font(TypographyTokens.standard)
                    }
                    Spacer(minLength: 0)
                }
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .workspaceCard()
            }
        }
        .padding(SpacingTokens.md)
        .frame(minWidth: 860)
        .background(ColorTokens.Workspace.canvas)
    }
}
