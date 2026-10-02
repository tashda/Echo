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
            .of("behaviour", "Behaviour", LabHSBehaviour.self, default: .collapse,
                question: "Scroll each card down and back up, and click the icons. How should the header and the icon menu behave as the list scrolls?",
                recommend: .collapse,
                why: "You asked for the menu to go first and then the header: that is this, with one change: the header does not go, it gets slim. The name is the one thing that tells you whose rows you are reading, and the banner shrinking to a slim bar with rounded corners is what removes the awful edge, since the rows go under a bar and not a cut. The menu is back with the first scroll up. HB3 is the one that does what you said literally, if you would rather the name leave too.",
                summary: \.summary),
            .of("edge", "Bottom corners", LabHSEdge.self, default: .round20,
                question: "Scroll with each corner radius. How round should the bottom of the pinned banner be?",
                recommend: .round20,
                why: "Concentric with the card's own corners at Corners 26 (20 is a step inside), so banner and card look like one family; 12 is for Corners 10."),
            .of("under", "Under the banner", LabHSUnder.self, default: .shadow,
                question: "Scroll slowly with each. What should the rows do as they pass under the banner?",
                recommend: .shadow,
                why: "A soft shadow says the banner is above the rows and costs nothing; the blur (UN2) is the more refined idea but blurs live text on every scroll frame, which the tree's own performance notes rule out for a list this long."),
            .of("slim", "Slim height", LabHSSlim.self, default: .medium,
                question: "Compare the slim bar's height (HB2, HB5).",
                recommend: .medium,
                why: "32pt holds a 15pt name with the eyebrow gone and is still a comfortable click target; 26 is tight, 40 is a banner again."),
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
            .init(id: "two", title: "Two behaviours",
                  summary: "HB2 and HB3 side by side with the chosen corners: scroll them the same distance.",
                  designWidth: 700, designHeight: 520) { values in
                HStack(spacing: SpacingTokens.sm) {
                    LabHSColumn { LabHSCard(look: LabHSLook(behaviour: .collapse, edge: LabHSLook(values).edge, under: LabHSLook(values).under, slim: LabHSLook(values).slim), server: sample(values)) }
                    LabHSColumn { LabHSCard(look: LabHSLook(behaviour: .follow, edge: LabHSLook(values).edge, under: LabHSLook(values).under, slim: LabHSLook(values).slim), server: sample(values)) }
                }
            },
        ],
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "The menu scrolls away, the banner shrinks to a slim bar with 20pt corners and a soft shadow.",
                  values: ["behaviour": LabHSBehaviour.collapse.rawValue, "edge": LabHSEdge.round20.rawValue, "under": LabHSUnder.shadow.rawValue,
                           "slim": LabHSSlim.medium.rawValue],
                  isRecommended: true),
            .init(id: "literal", name: "As you said", summary: "The menu first, then the header leaves.",
                  values: ["behaviour": LabHSBehaviour.follow.rawValue, "edge": LabHSEdge.round20.rawValue, "under": LabHSUnder.shadow.rawValue]),
            .init(id: "rounded", name: "Only the corners", summary: "The whole banner pinned, rounded, a shadow.",
                  values: ["behaviour": LabHSBehaviour.rounded.rawValue, "edge": LabHSEdge.round20.rawValue, "under": LabHSUnder.shadow.rawValue]),
        ]
    )

    private static func sample(_ values: RoundValues) -> LabSHServer {
        (LabSHSample(rawValue: values["sample"]) ?? .production).server
    }
}
