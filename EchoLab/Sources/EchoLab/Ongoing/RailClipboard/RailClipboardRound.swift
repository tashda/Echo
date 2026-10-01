import SwiftUI

/// Round 39.5 · Rail tools: Clipboard. Echo today (ClipboardHistoryView, ClipboardHistoryStore):
/// Echo keeps its own list of what you copied (cells, rows, queries) with a filter, a setting to
/// turn it off, and a popover per entry. macOS 26 keeps a clipboard history for every app in
/// Spotlight (⌘Space, then ⌘4), with its own retention and privacy settings.
@MainActor
enum RailClipboardRound {
    enum Fate: String, CaseIterable {
        case keep = "CB0 · Keep Echo's history as it is"
        case drop = "CB1 · Drop it; the system's clipboard history covers it"
        case recent = "CB2 · Drop the panel, keep Paste Recent in the editor's and grid's menus"

        var summary: String {
            switch self {
            case .keep: "A second history, only for Echo, with its own setting."
            case .drop: "Less to learn and secure; copies are still in Spotlight's history for 8 hours by default."
            case .recent: "The last five things copied in Echo, offered where you'd paste them, with no panel or setting."
            }
        }
    }

    static let spec = RoundSpec(
        controls: [
            .of("fate", "Clipboard", Fate.self, default: .drop,
                question: "Is a clipboard history inside Echo still worth having?",
                recommend: .drop,
                why: "macOS 26 now does it for every app, with search and the system's privacy controls; Echo's copy formats (Copy as CSV, as INSERT) are what makes copying from Echo good, and they stay in the menus. CB2 is the compromise if you often paste a value you copied a few minutes ago.",
                summary: \.summary),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Echo's own clipboard history in the tree's column.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 420) { _ in
                LabRTScene(selected: 3) {
                    LabRTColumn(title: "Clipboard", subtitle: "12 items", trailing: AnyView(Text("All ⌄").font(TypographyTokens.footnote).foregroundStyle(ColorTokens.Text.secondary))) {
                        ForEach([("tablecells", "AML_LAST_OH", "Cell · ESB_INTEGRATION · 15:35"), ("doc.text", "select * from dbo.aml_checkpoint", "Query · 15:34"),
                                 ("tablecells", "3 rows · keyName, keyValue, lastUpdated", "Rows · 15:33"), ("tablecells", "2610000125260", "Cell · ccsLDK10 · 15:20")], id: \.1) { item in
                            LabRTRow(symbol: item.0, title: item.1, detail: item.2)
                                .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: SpacingTokens.sm))
                                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                        }
                    }
                }
            },
            .init(id: "recent", title: "CB2 · Paste Recent", summary: "The editor's right-click menu with the last copies.", isWide: true, designWidth: 760, designHeight: 420) { _ in
                HStack(alignment: .top, spacing: SpacingTokens.md) {
                    LabWKEditor().workspaceCard()
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        ForEach(["Cut", "Copy", "Paste"], id: \.self) { Text($0) }
                        HStack { Text("Paste Recent"); Spacer(); Image(systemName: "chevron.right") }
                        Divider()
                        ForEach(["AML_LAST_OH", "2610000125260", "select * from dbo.aml_checkpoint"], id: \.self) {
                            Text($0).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                        }
                    }
                    .font(TypographyTokens.standard)
                    .padding(SpacingTokens.sm).frame(width: 240)
                    .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.sm))
                    .padding(.top, SpacingTokens.xxxl)
                }
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Workspace.canvas)
            },
        ],
        questions: [
            .init(id: "railAfter", title: "The rail's bottom pill",
                  question: "If Clipboard goes and 39.1 moves the library beside the editor, the bottom pill is empty. What happens to it?",
                  choices: [.init(id: "remove", name: "BP0 · It goes; the rail is only servers and +"),
                            .init(id: "library", name: "BP1 · It keeps one Library button")],
                  recommended: "library",
                  why: "One button where the four were keeps the library one click away from anywhere, as the bell is for notifications; ⇧⌘L stays the shortcut."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["fate": Fate.drop.rawValue], isRecommended: true)]
    )
}
