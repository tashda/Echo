import SwiftUI

/// Round 49 · Tool tabs: every page, calmer switching, icons. Changes TABS-5.1 to 5.4 (the pages in
/// the tab, and round 36.2's More menu), TABS-2.3 (the server dot on a tab), the tab icons, the tab
/// strip's motion, and FTR-2.4 (the server dot on the results footer's pill).
///
/// Echo today: QueryTabStrip+Unfold springs every tab's width on the house spring (a bounce), the
/// pages fade in at 40% of it, and TabPageChips moves what does not fit into More (TabPageOverflow).
/// Icons are WorkspaceTab+KindLabels (four tools share the lock shield or the wrench; `trace`, the
/// Profiler's, does not exist on macOS 26). The dot is QueryTabButton+Title and BottomPanelStatusBar.
@MainActor
enum ToolTabBarRound {
    private static func tool(_ v: RoundValues) -> LabTBarTool { LabTBarTool(rawValue: v["tool"]) ?? .activity }
    private static func window(_ v: RoundValues) -> LabTBarWindow { LabTBarWindow(rawValue: v["window"]) ?? .small }

    /// Query 1, the tool, Query 2 and Agent Jobs; with two servers the last two belong to the second.
    private static func tabs(_ v: RoundValues, advanced: LabTBarAdvanced) -> [LabTBarTab] {
        let part = LabTBarSplitPart(rawValue: v["part"]) ?? .types
        let second = (LabTBarServers(rawValue: v["servers"]) ?? .two) == .two ? 1 : 0
        let tool = tool(v)
        return [
            LabTBarTab(id: "q1", title: "Query 1", kind: .query, server: 0),
            LabTBarTab(id: "tool", title: tool.title(advanced, part: part), kind: .named(tool.kindName), server: 0, pages: tool.pages(advanced, part: part)),
            LabTBarTab(id: "q2", title: "Query 2", kind: .query, server: second),
            LabTBarTab(id: "jobs", title: "Agent Jobs", kind: .jobs, server: second),
        ]
    }

    private static func strip(_ v: RoundValues, today: Bool) -> some View {
        let advanced = today ? .all : (LabTBarAdvanced(rawValue: v["advanced"]) ?? .all)
        return LabTBarStrip(
            tabs: tabs(v, advanced: advanced), stripWidth: window(v).stripWidth,
            requestedFit: today ? .more : (LabTBarFit(rawValue: v["fit"]) ?? .adaptive),
            motionStyle: today ? .today : (LabTBarMotion(rawValue: v["motion"]) ?? .glide),
            icons: today ? .today : (LabTBarIcons(rawValue: v["icons"]) ?? .literal),
            tabDot: today ? .keep : (LabTBarTabDot(rawValue: v["tabDot"]) ?? .remove),
            firstActive: "tool")
            .padding(SpacingTokens.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ColorTokens.Workspace.canvas)
    }

    static let spec = RoundSpec(
        controls: [
            .of("tool", "Tool", LabTBarTool.self, default: .activity),
            .of("window", "Window", LabTBarWindow.self, default: .small),
            .of("servers", "Tabs from", LabTBarServers.self, default: .two),
            .of("part", "Split tool", LabTBarSplitPart.self, default: .types,
                question: nil, addedIn: 2),
            .of("advanced", "Advanced Objects", LabTBarAdvanced.self, default: .grouped,
                question: "Choose Advanced Objects above. Compare its thirteen pages, six shared pages, and four tools of their own (pick which one under Split tool). Which should it be?",
                recommend: .grouped,
                why: "Thirteen pages need 1,265 pt as chips: more than a 16-inch window's strip once other tabs are open, so no layout can show them all. Six pages (Types holds domains, composite and range types, with a segmented control inside the page) need 656 pt and fit everywhere. Keeping thirteen means More, which you just ruled out. Revision 2: you did not want pages sharing a page, so AO2 splits the folder into four tools of 2 to 4 pages (190 to 440 pt each); it is the cleaner answer if you do not mind four entries under Advanced Objects in the Explorer, and I would now ship it over AO1.",
                summary: \.summary, newChoices: (2, LabTBarAdvanced.revision2)),
            .of("fit", "Pages in the tab", LabTBarFit.self, default: .adaptive,
                question: "Pick Activity Monitor (11 pages) and the 13-inch window, then click through the other windows. How should every page always show?",
                recommend: .adaptive,
                why: "Measured at 11pt: Activity Monitor on PostgreSQL needs 990 pt, but a 13-inch window gives the tab 860 pt (980 pt strip, three tabs at 40 pt). Shorter names and tighter pages bring it to 799 pt, so it fits. FP4 does that and, only when even that cannot fit (a very narrow window), puts the pages in a row under the strip rather than hiding them. FP1 alone fails on the 13-inch laptop for two tools; FP2 moves every tool's pages out of the tab, which undoes round 36.1.",
                summary: \.summary),
            .of("motion", "Switching tabs", LabTBarMotion.self, default: .stillIcons,
                question: "Press Play on today's strip and then on each Proposal, with Fast on and off. Watch the icons and titles: do they stay put on their tab?",
                recommend: .stillIcons,
                why: "You picked the gliding plate (MO2) but not how the icon and title move: in MO2 an inactive tab's words are re-centred as its width changes, so they slide inside the tab. MO4 fixes each title to its tab's left edge, so words move only as far as the tab does, which reads as printed on it. MO5 keeps them still entirely, but they jump to their final place when you click, which the neighbouring tabs' words do too; I picked MO4 then because nothing jumps. Revision 3: in MO4 the icon still moved 2pt and changed colour as its tab changed, and every tab carries its labels as it resizes. MO6 freezes the labels completely (nothing about them animates, they ride the tab edge rigidly); MO7 takes them off the tab altogether onto a still layer so only the tabs and plate move. Revision 4: you liked MO4's motion best, so MO8 is MO4 with only the icon's 2pt slide removed (the same 14pt inset on every tab); MO6 and MO7 change more than that. I recommend MO8. Revision 5: in MO8 the icon still travels with its tab when a tool tab and a regular tab swap widths (the tabs to its left grow or shrink, so its tab's edge moves). MO9 keeps MO8 for everything else and puts only the icons on a still layer at their final positions, as you chose; I recommend MO9. If this is still not it, tell me what the icon should do in a sentence.",
                summary: \.summary, newChoices: (4, LabTBarMotion.revision3 + LabTBarMotion.revision4 + LabTBarMotion.revision5)),
            .of("icons", "Icons", LabTBarIcons.self, default: .literal,
                question: "Compare the icons in 'Every tab icon' and on the strips. Which set do you want?",
                recommend: .literal,
                why: "Today four tools share the lock shield or the wrench, and the Profiler's symbol does not exist on macOS 26, so its tab has no icon at all. IC1 gives each tool its own picture. Colour by family (IC2) is the runner-up but turns Manage orange, which reads as a warning. No icons (IC4) gives the pages about 20 pt per tab, but the icon is what tells a row of five tools apart.",
                summary: \.summary),
            .of("tabDot", "Server dot on tabs", LabTBarTabDot.self, default: .remove,
                question: "Set 'Tabs from' to one and two servers. Which dot do you want on the tabs?",
                recommend: .remove,
                why: "You do not like it. It adds a shape to every tab to say something the window's header colour and the tab's tooltip already say; with one server it says nothing. SD1 keeps what it is for (telling two servers apart) and is the pick if you do mix servers in one window.",
                summary: \.summary),
            .of("pillDot", "Server dot on the pill", LabTBarPillDot.self, default: .remove,
                question: "Look at the footer pill. Remove the dot?",
                recommend: .remove,
                why: "You asked for it. The pill already names the server."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "A tool tab, its pages and a More menu; the house spring. Press Play or click the tabs.",
                  isEchoToday: true, isWide: true, designWidth: 1500, designHeight: 170) { v in
                strip(v, today: true)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Press Play or click the tabs.",
                  isWide: true, designWidth: 1500, designHeight: 200) { v in
                strip(v, today: false)
            },
            .init(id: "measurements", title: "How much room the pages need", summary: "Measured at 11pt like Echo; which window each tool's pages fit.",
                  isWide: true, designWidth: 940, designHeight: 330) { _ in
                LabTBarMeasurements()
            },
            .init(id: "splitTools", title: "Advanced Objects as four tools", summary: "AO2: the thirteen pages and where each goes, with the room each tool needs.",
                  isWide: true, addedIn: 2, designWidth: 940, designHeight: 250) { _ in
                LabTBarSplitMap()
            },
            .init(id: "icons", title: "Every tab icon", summary: "Each kind of tab: the icon today, with the ones that repeat or do not exist, and the proposal.",
                  isWide: true, designWidth: 940, designHeight: 640) { v in
                LabTBarIconGallery(icons: LabTBarIcons(rawValue: v["icons"]) ?? .literal)
            },
            .init(id: "pill", title: "The results footer's pill", summary: "Server and database, with and without the dot.",
                  isWide: true, designWidth: 700, designHeight: 130) { v in
                LabTBarPillPair(proposalShowsDot: (LabTBarPillDot(rawValue: v["pillDot"]) ?? .remove) == .keep)
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Compact pages, a row only when needed, a gliding plate, new icons, no dots.",
                  values: ["advanced": LabTBarAdvanced.grouped.rawValue, "fit": LabTBarFit.adaptive.rawValue, "motion": LabTBarMotion.glide.rawValue,
                           "icons": LabTBarIcons.literal.rawValue, "tabDot": LabTBarTabDot.remove.rawValue, "pillDot": LabTBarPillDot.remove.rawValue],
                  isRecommended: true),
            .init(id: "longest", name: "The longest tool", summary: "Advanced Objects, all thirteen pages, in the 13-inch window.",
                  values: ["tool": LabTBarTool.advanced.rawValue, "advanced": LabTBarAdvanced.all.rawValue, "window": LabTBarWindow.small.rawValue]),
            .init(id: "plain", name: "Strip as today, only calmer", summary: "FP0 with MO1: pages and More stay; only the motion changes.",
                  values: ["fit": LabTBarFit.more.rawValue, "motion": LabTBarMotion.calm.rawValue, "icons": LabTBarIcons.today.rawValue,
                           "tabDot": LabTBarTabDot.keep.rawValue]),
        ]
    )
}
