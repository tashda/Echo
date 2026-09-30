import SwiftUI

/// Round 14 · EchoSense selection and corners, as a `RoundSpec`.
@MainActor
enum EchoSenseRound {
    static let spec = RoundSpec(
        controls: [
            .of("selection", "Selected suggestion", LabSenseSelection.self, default: .tintThenSolid,
                question: "Click line 1 and type (try Cu, Cr, T or Co). Watch the top row while typing, then press ↓ and ↑. Which selection style?",
                recommend: .tintThenSolid,
                why: "ESR4: tinted while typing and solid once you use the arrows, so the solid state tells you Return inserts it."),
            .of("corners", "Popup corners", LabSenseCorners.self, default: .followCards,
                question: "Switch Card Corners from 10 to 26 and watch the popup. Should it follow the setting?",
                recommend: .followCards,
                why: "ESR5: the popup takes the card material and follows Card Corners, capped at 14pt so the rows inside keep parallel curves."),
            .of("cardCorners", "Card Corners setting", LabCardCornerSetting.self, default: .sixteen),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Solid selection, a fixed 10pt corner.", isEchoToday: true,
                  designWidth: LayoutTokens.DesignLabRound14.senseEditorWidth + 32, designHeight: LayoutTokens.DesignLabRound14.senseEditorHeight + 32) { values in
                SenseSpecimen(selection: .alwaysSolid, corners: .fixed, cardCorners: LabCardCornerSetting(rawValue: values["cardCorners"]) ?? .sixteen)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click line 1 and type.",
                  designWidth: LayoutTokens.DesignLabRound14.senseEditorWidth + 32, designHeight: LayoutTokens.DesignLabRound14.senseEditorHeight + 32) { values in
                SenseSpecimen(selection: LabSenseSelection(rawValue: values["selection"]) ?? .tintThenSolid,
                              corners: LabSenseCorners(rawValue: values["corners"]) ?? .followCards,
                              cardCorners: LabCardCornerSetting(rawValue: values["cardCorners"]) ?? .sixteen)
            },
        ]
    )
}

private struct SenseSpecimen: View {
    let selection: LabSenseSelection
    let corners: LabSenseCorners
    let cardCorners: LabCardCornerSetting

    var body: some View {
        LabRound14SenseEditor(selection: selection, corners: corners)
            .environment(\.workspaceCardCornerRadius, cardCorners.radius)
            .padding(SpacingTokens.md)
    }
}
