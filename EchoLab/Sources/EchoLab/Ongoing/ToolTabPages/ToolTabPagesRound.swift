import SwiftUI

/// Round 36.1 · Tool tabs with pages: the tab bar. Echo today (TabPageChips, QueryTabStrip+Unfold,
/// ST2 from round 14): the active Activity Monitor tab widens (up to 62% of the strip) and shows its
/// pages as 10pt chips on a grey track capsule inside the tab's raised capsule; alone, it fills the
/// whole strip. The owner sees a pill in a pill that looks buggy, and a hideous strip with one tab.
@MainActor
enum ToolTabPagesRound {
    static let spec = RoundSpec(
        controls: [
            .of("style", "Pages", LabTPStyle.self, default: .segments,
                question: "Click through the pages in every style, with three tabs and with Activity Monitor alone. Which looks like it belongs in the strip?",
                recommend: .segments,
                why: "The strip already has one shape that means 'you are here': the raised plate. TP2 lets that plate move between the pages, so there is no second pill and nothing nested. TP1 is lighter but its dot is a new mark; TP4 is the fallback if pages in the strip still feel crowded with many tabs.",
                summary: \.summary),
            .of("single", "One tab", LabTPSingle.self, default: .leading,
                question: "Look at the strip with Activity Monitor alone.",
                recommend: .leading,
                why: "A single tab stretched across the strip makes the title and pages float in a long empty capsule, which is what looks wrong. At its own width it reads as one tab, where the next tab will appear; centred puts it away from the + button and the tree's edge."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Three tabs, Activity Monitor active.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 160) { _ in
                LabTPExhibit(style: .today, single: .fill, alone: false)
            },
            .init(id: "todayAlone", title: "Echo today, alone", summary: "Activity Monitor as the only tab.",
                  isEchoToday: true, isWide: true, designWidth: 860, designHeight: 160) { _ in
                LabTPExhibit(style: .today, single: .fill, alone: true)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click the pages.",
                  isWide: true, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: LabTPStyle(rawValue: values["style"]) ?? .segments, single: LabTPSingle(rawValue: values["single"]) ?? .leading, alone: false)
            },
            .init(id: "proposalAlone", title: "Proposal, alone", summary: "Built from the controls.",
                  isWide: true, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: LabTPStyle(rawValue: values["style"]) ?? .segments, single: LabTPSingle(rawValue: values["single"]) ?? .leading, alone: true)
            },
            .init(id: "all", title: "Every style", summary: "The five styles, three tabs each.",
                  isWide: true, designWidth: 860, designHeight: 420) { values in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(LabTPStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        LabTPStrip(tabs: [.query2, .jobs, .activityMonitor], activeID: "am", style: style)
                    }
                }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
            },
        ],
        questions: [
            .init(id: "switching", title: "Switching tabs",
                  question: "When you switch from Activity Monitor to Query 2, its pages fold away. How?",
                  choices: [
                      .init(id: "snappy", name: "UF0 · The tab narrows on a snappy 0.32 s curve and the pages fade (today)"),
                      .init(id: "spring", name: "UF1 · The house spring, the pages fading first"),
                  ],
                  recommended: "spring",
                  why: "Every other moving part of the window uses the house spring (EchoMotion.standard); the strip's own snappy curve is the one exception. Fading the pages first keeps text from squeezing as the tab narrows."),
        ],
        exhibitTopic: ("Which tab bar?", "Do the Proposal's strips look finished, with three tabs and alone?", "proposal",
                       "One raised plate moving between the pages, and a lone tab at its own width."),
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["style": LabTPStyle.segments.rawValue, "single": LabTPSingle.leading.rawValue], isRecommended: true),
            .init(id: "quiet", name: "Pages in the tab", summary: "The strip stays plain; the tool's header has the pages.",
                  values: ["style": LabTPStyle.inTab.rawValue, "single": LabTPSingle.leading.rawValue]),
        ]
    )
}

/// The strip over the top of the tool's card.
struct LabTPExhibit: View {
    let style: LabTPStyle
    let single: LabTPSingle
    let alone: Bool
    var tool: LabTPTab = .activityMonitor

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            LabTPStrip(tabs: alone ? [tool] : [.query2, .jobs, tool], activeID: tool.id, style: style, single: single)
            VStack(spacing: SpacingTokens.none) {
                if style == .inTab { LabTPInTabHeader(tab: tool) }
                HStack {
                    Image(systemName: tool.symbol).foregroundStyle(ColorTokens.Status.warning)
                    Text(tool.title).font(TypographyTokens.headline)
                    Text("dkloosql10-p").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                }
                .padding(SpacingTokens.sm)
                Spacer(minLength: 0)
            }
            .workspaceCard()
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }
}
