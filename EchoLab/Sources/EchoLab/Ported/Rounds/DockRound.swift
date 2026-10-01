import SwiftUI

/// Round 14's section dock as a `RoundSpec` (the pilot for the round format): Echo today and a
/// proposal driven by three controls.
@MainActor
enum DockRound {
    static let spec = RoundSpec(
        controls: [
            .of("icons", "Icon style", LabDockIconMode.self, default: .duotone,
                question: "Which icon style should the dock and the rows use by default? Duotone is the outline in the role's colour over its fill; mono is one quiet colour and stays a setting.",
                recommend: .duotone,
                why: "You decided IC2 duotone as the default and mono as a setting; it is what Echo ships."),
            .of("labels", "Dock labels", LabDockLabels.self, default: .iconsOnly,
                question: "Should the dock show which section you are in as text? Switch between Databases, Security and Agent and read where you are.",
                recommend: .iconsOnly,
                why: "You accepted icons only (TC1); the current one on the grey selection fill already says where you are, and a title costs width."),
            .of("edge", "Edge under the dock", LabDockEdge.self, default: .soft,
                question: "How should rows look as they scroll under the pinned dock? Scroll slowly and watch the dock's lower edge.",
                recommend: .soft,
                why: "You decided on only a soft blur, with no background and no line."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Duotone icons, icons only, a soft edge.", isEchoToday: true,
                  designWidth: LayoutTokens.DesignLabRound14.dockCardWidth, designHeight: LayoutTokens.DesignLabRound14.dockCardHeight) { _ in
                DockSpecimen(icons: .duotone, labels: .iconsOnly, edge: .soft)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls above.",
                  designWidth: LayoutTokens.DesignLabRound14.dockCardWidth, designHeight: LayoutTokens.DesignLabRound14.dockCardHeight) { values in
                DockSpecimen(icons: LabDockIconMode(rawValue: values["icons"]) ?? .duotone,
                             labels: LabDockLabels(rawValue: values["labels"]) ?? .iconsOnly,
                             edge: LabDockEdge(rawValue: values["edge"]) ?? .soft)
            },
        ]
    )
}

private struct DockSpecimen: View {
    let icons: LabDockIconMode
    let labels: LabDockLabels
    let edge: LabDockEdge
    @Environment(\.echoMotion) private var motion

    var body: some View {
        LabRound14DockCard(iconMode: icons, labels: labels, edge: edge, animation: motion.standard)
    }
}
