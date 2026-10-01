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
        controls: [
            .of("source", "Snippets", Source.self, default: .yours,
                question: "Should you be able to write your own snippets?",
                recommend: .yours,
                why: "Your own are why a snippet list is worth a place in the window; built-ins are shared by everyone and can stay quietly below."),
            .of("insert", "Inserting", Insert.self, default: .all,
                question: "How should a snippet get into the editor?",
                recommend: .all,
                why: "Typing a prefix (sel, tran) is fastest once learned and goes through EchoSense, which already ranks completions; the list is for discovering them."),
            .of("placeholders", "Blanks", Placeholders.self, default: .tabStops,
                question: "Should snippets have fields you Tab through?",
                recommend: .tabStops,
                why: "A snippet is a pattern with blanks: Xcode, VS Code and SSMS's templates all fill them with Tab. The placeholder marks use the editor's mark language (28.15)."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Built-in snippets for SQL Server, grouped.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { _ in
                LabRTScene(selected: 1) {
                    LabRTColumn(title: "Snippets", subtitle: "SQL Server") {
                        ForEach(["Queries", "Transactions", "Server"], id: \.self) { group in
                            LabRTHeading(title: group.uppercased())
                            ForEach(LabRTSnippet.samples.filter { $0.group == group }) { LabRTRow(symbol: "curlybraces", title: $0.name, detail: $0.body) }
                        }
                    }
                }
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls; the editor shows a snippet being filled in.", isWide: true, designWidth: 760, designHeight: 440) { values in
                LabRSProposal(source: Source(rawValue: values["source"]) ?? .yours, insert: Insert(rawValue: values["insert"]) ?? .all,
                              placeholders: Placeholders(rawValue: values["placeholders"]) ?? .tabStops)
            },
        ],
        questions: [
            .init(id: "create", title: "Making one",
                  question: "Where do you make a snippet?",
                  choices: [.init(id: "selection", name: "SN0 · Select SQL › right-click › New Snippet from Selection, and + in the list"),
                            .init(id: "settings", name: "SN1 · In Settings › Snippets only")],
                  recommended: "selection",
                  why: "You notice you want a snippet while looking at the SQL; making it from there takes the text with it."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["source": Source.yours.rawValue, "insert": Insert.all.rawValue, "placeholders": Placeholders.tabStops.rawValue], isRecommended: true)]
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
