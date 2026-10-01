import SwiftUI

/// Round 36.1 · Tool tabs with pages: the tab bar. Echo today (TabPageChips, QueryTabStrip+Unfold,
/// ST2 from round 14): the active Activity Monitor tab widens (up to 62% of the strip) and shows its
/// pages as 10pt chips on a grey track capsule inside the tab's raised capsule; alone, it fills the
/// whole strip. The owner sees a pill in a pill that looks buggy, and a hideous strip with one tab.
/// Revision 2: the owner found TP0 closest but still a tab inside a tab with the title sitting on it,
/// and confirmed the pages stay in the tab bar (not the tool's header). Added TP5 to TP7.
/// Revision 3: the owner likes TP0 best (the title, then its pages to the right) but not the grey
/// sitting off centre, and set the other styles aside: TP0 refined, one knob per fix.
@MainActor
enum ToolTabPagesRound {
    private static func refine(_ values: RoundValues) -> LabTPRefine { LabTPRefine.from(values) }
    private static func single(_ values: RoundValues) -> LabTPSingle { LabTPSingle(rawValue: values["single"]) ?? .leading }

    static let spec = RoundSpec(
        controls: [
            .of("width", "Tab width", LabTPWidth.self, default: .hug,
                question: "Compare RW0 and RW1 in 'TP0 refined'. Should the active tab be as wide as what it holds?",
                recommend: .hug,
                why: "Today the tab stretches to 62% of the strip and centres the title and pages in it, which leaves white at both ends and puts the grey off centre. As wide as its content, the white ends exactly where the pages end, like every other tab in the strip.",
                addedIn: 3),
            .of("track", "Grey track", LabTPTrack.self, default: .docked,
                question: "Switch the track between RT0, RT1 and RT2 and look at the right end of the tab.",
                recommend: .docked,
                why: "Docked 2pt inside the tab's right end, the track's curve runs parallel to the tab's, so the grey reads as part of the tab (like the segments in a macOS toolbar) instead of a second pill dropped into it. RT2 is the quietest, but without the grey the pages stop looking like a set you switch between.",
                addedIn: 3),
            .of("text", "Type", LabTPText.self, default: .matched,
                question: "Look at the title and the pages together. Should they be one size?",
                recommend: .matched,
                why: "At 10pt beside an 11pt title the pages look like small print; at 11pt on one baseline the line reads as one sentence. The title in medium and the shown page in semibold keep them apart without a size jump.",
                addedIn: 3),
            .of("divider", "Between", LabTPDivider.self, default: .none,
                question: "Is the space between the title and the pages enough, or does it need a hairline?",
                recommend: .none,
                why: "With the track docked, the grey already starts where the pages start, so a hairline adds a third mark for the same boundary.",
                addedIn: 3),
            .of("chip", "Shown page", LabTPChip.self, default: .raised,
                question: "Click through the pages. Should the shown page be white and raised, or tinted with the tool's colour?",
                recommend: .raised,
                why: "White and raised is how macOS shows the selected segment and how the strip shows the active tab, so it needs no explaining. The tint ties the page to the tool's icon, but orange on Activity Monitor and red on Database Security will read as warnings.",
                addedIn: 3),
            .of("single", "One tab", LabTPSingle.self, default: .leading,
                question: "Look at 'TP0 refined, alone'.",
                recommend: .leading,
                why: "A single tab stretched across the strip makes the title and pages float in a long empty capsule, which is what looked hideous. At its own width it reads as one tab, where the next tab will appear; centred puts it away from the + button and the tree's edge."),
            .of("style", "Earlier styles", LabTPStyle.self, default: .today,
                summary: \.summary, newChoices: (2, LabTPStyle.revision2)),
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
            .init(id: "refined", title: "TP0 refined", summary: "Built from the controls. Click the pages.",
                  isWide: true, addedIn: 3, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: .today, single: single(values), alone: false, refine: refine(values))
            },
            .init(id: "refinedAlone", title: "TP0 refined, alone", summary: "Activity Monitor as the only tab.",
                  isWide: true, addedIn: 3, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: .today, single: single(values), alone: true, refine: refine(values))
            },
            .init(id: "refinedMany", title: "TP0 refined, more tools", summary: "Policy Management, Server Properties, and Database Security's nine pages ending in a menu (36.2, OF1).",
                  isWide: true, addedIn: 3, designWidth: 860, designHeight: 170) { values in
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    ForEach([LabTPTab.policy, .serverProperties, .dbSecurity]) { tool in
                        LabTPStrip(tabs: [.query2, .jobs, tool], activeID: tool.id, style: .today, refine: refine(values))
                    }
                }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Workspace.canvas)
            },
            .init(id: "steps", title: "From today to refined, one fix at a time", summary: "Each row adds one fix to the row above.",
                  isWide: true, addedIn: 3, designWidth: 860, designHeight: 330) { _ in
                LabTPSteps()
            },
            .init(id: "proposal", title: "Earlier styles", summary: "TP1 to TP7, from the Earlier styles control.",
                  isWide: true, designWidth: 860, designHeight: 160) { values in
                LabTPExhibit(style: LabTPStyle(rawValue: values["style"]) ?? .today, single: single(values), alone: false)
            },
            .init(id: "revision2", title: "Revision 2's styles", summary: "TP5, TP6 and TP7, three tabs each, then alone.",
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
        exhibitTopic: ("Which tab bar?", "Is 'TP0 refined' finished, with three tabs, alone and with nine pages?", "refined",
                       "TP0 as you liked it, with the four fixes: the tab as wide as its content, the grey docked to its right end, one type size, the shown page white and raised."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "TP0 with every fix.",
                  values: ["width": LabTPWidth.hug.rawValue, "track": LabTPTrack.docked.rawValue, "text": LabTPText.matched.rawValue,
                           "divider": LabTPDivider.none.rawValue, "chip": LabTPChip.raised.rawValue, "single": LabTPSingle.leading.rawValue],
                  isRecommended: true),
            .init(id: "quietest", name: "Quietest", summary: "No grey track; the shown page on a soft grey pill.",
                  values: ["width": LabTPWidth.hug.rawValue, "track": LabTPTrack.none.rawValue, "text": LabTPText.matched.rawValue,
                           "divider": LabTPDivider.none.rawValue, "chip": LabTPChip.raised.rawValue, "single": LabTPSingle.leading.rawValue]),
            .init(id: "today", name: "Echo today", summary: "Every knob at today's value.",
                  values: ["width": LabTPWidth.fill.rawValue, "track": LabTPTrack.floating.rawValue, "text": LabTPText.today.rawValue,
                           "divider": LabTPDivider.none.rawValue, "chip": LabTPChip.raised.rawValue, "single": LabTPSingle.fill.rawValue]),
        ]
    )
}

/// Today, then one fix at a time, ending at the recommendation.
struct LabTPSteps: View {
    private static let steps: [(String, LabTPRefine?)] = [
        ("Echo today", nil),
        ("1 · As wide as its content", LabTPRefine(width: .hug, track: .floating, text: .today)),
        ("2 · The grey docked to the right end", LabTPRefine(width: .hug, track: .docked, text: .today)),
        ("3 · One type size", LabTPRefine.recommended),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            ForEach(Self.steps, id: \.0) { step in
                Text(step.0).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                LabTPStrip(tabs: [.query2, .jobs, .activityMonitor], activeID: "am", style: .today, refine: step.1)
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }
}

/// The strip over the top of the tool's card.
struct LabTPExhibit: View {
    let style: LabTPStyle
    let single: LabTPSingle
    let alone: Bool
    var tool: LabTPTab = .activityMonitor
    var refine: LabTPRefine? = nil

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            LabTPStrip(tabs: alone ? [tool] : [.query2, .jobs, tool], activeID: tool.id, style: style, single: single, refine: refine)
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
