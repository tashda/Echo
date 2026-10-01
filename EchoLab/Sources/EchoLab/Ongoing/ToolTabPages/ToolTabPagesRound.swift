import SwiftUI

/// Round 36.1 · Tool tabs with pages: the tab bar. Echo today (TabPageChips, QueryTabStrip+Unfold,
/// ST2 from round 14): the active Activity Monitor tab widens (up to 62% of the strip) and shows its
/// pages as 10pt chips on a grey track capsule inside the tab's raised capsule; alone, it fills the
/// whole strip. The owner sees a pill in a pill that looks buggy, and a hideous strip with one tab.
/// Revision 2: the owner found TP0 closest but still a tab inside a tab with the title sitting on it,
/// and confirmed the pages stay in the tab bar (not the tool's header). Added TP5 to TP7.
@MainActor
enum ToolTabPagesRound {
    static let spec = RoundSpec(
        controls: [
            .of("style", "Pages", LabTPStyle.self, default: .group,
                question: "Click through the pages in TP5, TP6 and TP7, with three tabs and with Activity Monitor alone. Which looks like it belongs in the strip?",
                recommend: .group,
                why: "You disliked a shape inside the tab and the title sitting on it. TP5 removes both: the title becomes a tinted label (as Safari and Chrome mark a tab group) and each page is an ordinary tab, so the strip has one shape and the plate only ever means 'shown'. TP6 is quieter but its accent words are a new mark in the strip; TP7 has the most room (nine pages) but adds a row under the strip.",
                summary: \.summary, newChoices: (2, LabTPStyle.revision2)),
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
                LabTPExhibit(style: LabTPStyle(rawValue: values["style"]) ?? .group, single: LabTPSingle(rawValue: values["single"]) ?? .leading, alone: false)
            },
            .init(id: "proposalAlone", title: "Proposal, alone", summary: "Built from the controls.",
                  isWide: true, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: LabTPStyle(rawValue: values["style"]) ?? .group, single: LabTPSingle(rawValue: values["single"]) ?? .leading, alone: true)
            },
            .init(id: "revision2", title: "The new styles", summary: "TP5, TP6 and TP7, three tabs each, then alone. Click the pages.",
                  isWide: true, addedIn: 2, designWidth: 860, designHeight: 420) { _ in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(LabTPStyle.revision2, id: \.self) { style in
                        Text(style.rawValue).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                        LabTPStrip(tabs: [.query2, .jobs, .activityMonitor], activeID: "am", style: style)
                        LabTPStrip(tabs: [.activityMonitor], activeID: "am", style: style, single: .leading)
                    }
                }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
            },
            .init(id: "nine", title: "Nine pages", summary: "Database Security in the Proposal's style: five pages, then More (36.2, OF1).",
                  isWide: true, addedIn: 2, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: LabTPStyle(rawValue: values["style"]) ?? .group, single: LabTPSingle(rawValue: values["single"]) ?? .leading,
                             alone: false, tool: .dbSecurity)
            },
            .init(id: "all", title: "Every style", summary: "The first five styles, three tabs each.",
                  isWide: true, designWidth: 860, designHeight: 420) { values in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach(LabTPStyle.allCases.filter { !LabTPStyle.revision2.contains($0) }, id: \.self) { style in
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
                       "TP5: the tool's name as a tinted label and its pages as ordinary tabs, so nothing sits inside a tab; a lone tool at its own width."),
        presets: [
            .init(id: "recommended", name: "My recommendation", values: ["style": LabTPStyle.group.rawValue, "single": LabTPSingle.leading.rawValue], isRecommended: true),
            .init(id: "hanging", name: "Room for many pages", summary: "TP7: the pages in a row hanging under the tab.",
                  values: ["style": LabTPStyle.hanging.rawValue, "single": LabTPSingle.leading.rawValue]),
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
