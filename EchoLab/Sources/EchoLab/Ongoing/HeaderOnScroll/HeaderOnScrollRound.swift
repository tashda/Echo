import SwiftUI

/// Round 57 · The card header while the list scrolls. Today the banner (name and icon menu) is pinned and the
/// rows are cut by its straight bottom edge. The owner finds it awful and suggests rounded bottom
/// corners, or scrolling the icon menu away first and then the header. Changes TREE-2.1 and the
/// section dock (TREE-3).
@MainActor
enum HeaderOnScrollRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xl

    static let spec = RoundSpec(
        controls: [
            .of("behaviour", "Behaviour", LabHSBehaviour.self, default: .pill,
                question: "Scroll each card down and back up (slowly at first: the menu morphs over the first 60pt) and click the icons. How should the header and the icon menu behave?",
                recommend: .pillName,
                why: "You liked HB5's idea (the header goes, the menu stays) and asked for either the name on top or the menu as a glass pill. One capsule that carries the name on its left and the five icons on its right does both: the banner's colour clears into glass as it narrows, so it is the pill you remember, and the name, the one thing that says whose list you are reading, is never far. The trail also shows the server, so HB3 (icons only) is fine if you want the pill smaller; HB1 is the plainest.",
                summary: \.summary),
            .of("material", "The pill", LabHSMaterial.self, default: .tinted,
                question: "Choose a pill behaviour (HB3 to HB5) and compare the materials.",
                recommend: .tinted,
                why: "Clear glass over a white list is nearly invisible, which is why the old glass menu looked lost; a 35% tint of the server's colour gives the pill an identity (red for production) with no banner. The solid pill is the banner shrunk, the loudest.",
                summary: \.summary),
            .of("edge", "Bottom corners", LabHSEdge.self, default: .round20,
                question: "For the bar (HB1 and HB2): how round should its bottom corners be?",
                recommend: .round20,
                why: "A step inside the card's own corners at Corners 26, so bar and card look like one family; 12 for Corners 10."),
            .of("slim", "Bar height", LabHSSlim.self, default: .medium),
            .of("under", "Under the pinned part", LabHSUnder.self, default: .shadow),
            .of("sample", "Server", LabSHSample.self, default: .production),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today",
                  summary: "The banner pinned with a hard edge. Scroll the list.",
                  isEchoToday: true, designWidth: width, designHeight: 520) { values in
                LabHSColumn { LabHSCard(look: .today, server: sample(values)) }
            },
            .init(id: "proposal", title: "Proposal",
                  summary: "Built from the controls. Scroll the list down and up; click the icons.",
                  designWidth: width, designHeight: 520) { values in
                LabHSColumn { LabHSCard(look: LabHSLook(values), server: sample(values)) }
            },
            .init(id: "three", title: "Three behaviours",
                  summary: "HB1 (the bar), HB3 (the pill) and HB4 (the pill with the name) with the chosen material: scroll them the same distance.",
                  designWidth: 700, designHeight: 520) { values in
                let base = LabHSLook(values)
                HStack(spacing: SpacingTokens.xs) {
                    ForEach([LabHSBehaviour.bar, .pill, .pillName], id: \.self) { behaviour in
                        LabHSColumn {
                            LabHSCard(look: LabHSLook(behaviour: behaviour, material: base.material, edge: base.edge, under: base.under, slim: base.slim),
                                      server: sample(values))
                        }
                    }
                }
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "One tinted glass pill with the name and the five icons.",
                  values: ["behaviour": LabHSBehaviour.pillName.rawValue, "material": LabHSMaterial.tinted.rawValue, "under": LabHSUnder.shadow.rawValue],
                  isRecommended: true),
            .init(id: "bar", name: "The bar you liked", summary: "HB5 as it was: the menu pinned as a slim bar.",
                  values: ["behaviour": LabHSBehaviour.bar.rawValue, "edge": LabHSEdge.round20.rawValue, "under": LabHSUnder.shadow.rawValue]),
            .init(id: "chips", name: "Two objects", summary: "A name chip and the menu pill, clear glass.",
                  values: ["behaviour": LabHSBehaviour.chips.rawValue, "material": LabHSMaterial.glass.rawValue, "under": LabHSUnder.shadow.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}
