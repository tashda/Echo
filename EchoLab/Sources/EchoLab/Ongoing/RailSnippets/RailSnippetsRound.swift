import SwiftUI

/// Round 39.3 · Rail tools: Snippets. Echo today (SnippetsSidebarView): the built-in
/// `SQLSnippetCatalog` for the active connection's dialect, grouped, with no way to add your own;
/// "No Active Connection" when nothing is connected.
@MainActor
enum RailSnippetsRound {
    enum Source: String, CaseIterable {
        case builtIn = "SS0 · Built-in only (today)"
        case yours = "SS1 · Yours first, then built-in"
    }

    enum Insert: String, CaseIterable {
        case click = "SI0 · Click inserts at the caret"
        case all = "SI1 · Click, drag, or type its prefix in the editor and press Tab"
    }

    enum Placeholders: String, CaseIterable {
        case none = "SP0 · Plain text"
        case tabStops = "SP1 · ${table} placeholders you Tab through, as in Xcode"
    }

    static let spec = RoundSpec(
        controls: [],
        exhibits: [
            .init(id: "removed", title: "Removed · Snippets", summary: "Owner: Remove snippets; KS2 accepted in 39.1. No Snippets panel or palette items. Bookmarks retain saved queries.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 520) { _ in
                RailToolsAcceptedScene()
            },
        ], questions: []
    )

}

private struct LabRSProposal: View {
    let source: RailSnippetsRound.Source
    let insert: RailSnippetsRound.Insert
    let placeholders: RailSnippetsRound.Placeholders

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            LabRTRail(selected: 1)
            LabRTColumn(title: "Snippets", subtitle: "SQL Server", trailing: AnyView(Image(systemName: "plus").foregroundStyle(ColorTokens.Text.secondary))) {
                LabRTSearch(prompt: "Search snippets")
                if source == .yours {
                    LabRTHeading(title: "Yours", count: 2)
                    ForEach(LabRTSnippet.samples.filter(\.isYours)) { LabRTRow(symbol: "curlybraces", tint: ColorTokens.accent, title: $0.name, detail: $0.body, trailing: $0.prefix) }
                }
                LabRTHeading(title: "Built in", count: 3)
                ForEach(LabRTSnippet.samples.filter { !$0.isYours }) { LabRTRow(symbol: "curlybraces", title: $0.name, detail: $0.body, trailing: insert == .all ? $0.prefix : nil) }
            }
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.none) {
                    Text("UPDATE aml_checkpoint SET keyValue = '").font(TypographyTokens.code)
                    placeholder("date", active: true)
                    Text("' WHERE keyName = '").font(TypographyTokens.code)
                    placeholder("key", active: false)
                    Text("'").font(TypographyTokens.code)
                }
                if insert == .all {
                    Text("Typed amlreset, then Tab: the fields are ready to fill; Tab moves to the next.")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
                Spacer()
            }
            .padding(SpacingTokens.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .workspaceCard()
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    @ViewBuilder
    private func placeholder(_ name: String, active: Bool) -> some View {
        if placeholders == .tabStops {
            Text(name).font(TypographyTokens.code)
                .padding(.horizontal, SpacingTokens.xxxs)
                .background(ColorTokens.accent.opacity(active ? 0.22 : 0.1), in: Capsule())
        } else {
            Text("${\(name)}").font(TypographyTokens.code).foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
