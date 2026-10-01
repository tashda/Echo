import SwiftUI

/// Round 19 · Section dock, page 1: switching. The tree is built the way Echo builds it (one flat
/// lazy list, stacked cards drawn behind it), so what is judged here is what Echo will do.
/// Changes TREE-3.7 (switching sections) and TREE-1.2 (one card per server).
@MainActor
enum SectionDockSwitchingRound {
    private static let width = LayoutTokens.Workspace.treeIdealWidth + SpacingTokens.xxxl
    private static let height = SpacingTokens.xxxl * 9

    static let spec = RoundSpec(
        controls: [
            .of("switch", "Switching", LabSDSwitch.self, default: .fadeThrough,
                question: "Click through Test MSSQL's icons in both exhibits, at Default and Fast speed. Which change is smooth enough, with nothing sliding in from the bottom?",
                recommend: .fadeThrough,
                why: "Nothing moves but the card's bottom edge, and it works on Echo's lazy list, so it stays smooth with thousands of rows. S1 overlaps two sets of rows while the height changes and must draw the whole section at once; S2 and S5 are abrupt; S4 suggests an order the sections don't have.",
                summary: \.summary),
            .of("scroll", "Where the view goes", LabSDSwitchScroll.self, default: .jump,
                question: "Scroll down inside Databases, switch to Security and back. Should the view glide, stay, or jump back to where you were?",
                recommend: .jump,
                why: "You decided each section keeps its scroll position (TC1). Jumping keeps that without the glide that moves every row on screen; with a fade-through, the jump happens while the rows are faded, so it isn't seen. Stay put is the calmest but forgets your place.",
                summary: \.summary),
            .of("neighbours", "The other cards", LabSDNeighbours.self, default: .holdPosition,
                question: "Press Scroll to Test MSSQL, then switch it to Security, and collapse it. Watch postgres18's card above it: it must not move.",
                recommend: .holdPosition,
                why: "Only N2 keeps the card above perfectly still: N1 stops it animating, but when the list gets shorter the view still scrolls back and jumps it. The room N2 leaves below the last card disappears as you scroll up.",
                summary: \.summary),
        ],
        actions: [
            .init(id: "scroll", title: "Scroll to Test MSSQL", symbol: "arrow.down.to.line") { $0["scrollToken"] = UUID().uuidString },
            .init(id: "reset", title: "Reset both trees", symbol: "arrow.counterclockwise") { $0["resetToken"] = UUID().uuidString },
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Round 16 as built (f054cc97): rows fade one by one, the list animates them into place, the view glides, and every card animates.",
                  isEchoToday: true, designWidth: width, designHeight: height) { values in
                tree(.today, values)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls: switching, where the view goes, and what the other cards do.",
                  designWidth: width, designHeight: height) { values in
                tree(options(values), values)
            },
        ],
        presets: [
            .init(id: "recommended", name: "Fade through, jump, hold", summary: "My recommendation.", values: [
                "switch": LabSDSwitch.fadeThrough.rawValue, "scroll": LabSDSwitchScroll.jump.rawValue, "neighbours": LabSDNeighbours.holdPosition.rawValue,
            ], isRecommended: true),
            .init(id: "calm", name: "Calmest", summary: "The rows swap, only the edge settles, nothing scrolls.", values: [
                "switch": LabSDSwitch.swapAndSettle.rawValue, "scroll": LabSDSwitchScroll.stay.rawValue, "neighbours": LabSDNeighbours.holdPosition.rawValue,
            ]),
            .init(id: "block", name: "Card crossfade", summary: "The rows change as one piece.", values: [
                "switch": LabSDSwitch.cardCrossfade.rawValue, "scroll": LabSDSwitchScroll.jump.rawValue, "neighbours": LabSDNeighbours.holdPosition.rawValue,
            ]),
            .init(id: "today", name: "As today", summary: "Every control on what Echo does now.", values: [
                "switch": LabSDSwitch.today.rawValue, "scroll": LabSDSwitchScroll.today.rawValue, "neighbours": LabSDNeighbours.today.rawValue,
            ]),
        ]
    )

    private static func options(_ values: RoundValues) -> LabSDOptions {
        var options = LabSDOptions.today
        options.usesBlueprintDock = true
        options.switchMotion = LabSDSwitch(rawValue: values["switch"]) ?? .fadeThrough
        options.switchScroll = LabSDSwitchScroll(rawValue: values["scroll"]) ?? .jump
        options.neighbours = LabSDNeighbours(rawValue: values["neighbours"]) ?? .holdPosition
        return options
    }

    private static func tree(_ options: LabSDOptions, _ values: RoundValues) -> some View {
        LabSDTreeView(servers: LabSDSamples.servers(grouping: .today), options: options,
                      resetToken: values["resetToken"], scrollToken: values["scrollToken"])
            .padding(SpacingTokens.sm)
            .background(ColorTokens.Workspace.canvas)
    }
}
