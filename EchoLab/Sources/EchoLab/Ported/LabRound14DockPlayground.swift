import SwiftUI

/// Round 14 · TC1 section dock, the one tree layout kept as Maybe. Two cards side by side so the
/// icon modes (IC2 duotone, the default, and IC1 mono, the setting) can be compared.
struct LabRound14DockPlayground: View {
    @State private var labels: LabDockLabels = .iconsOnly
    @State private var edge: LabDockEdge = .soft
    @State private var speed: LabSpeed = .standard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LabStage(title: "Section dock") {
            LabPicker(title: "Dock", selection: $labels, options: LabDockLabels.allCases)
            LabPicker(title: "Edge", selection: $edge, options: LabDockEdge.allCases)
            LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
        } content: {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Text("Scroll a section, expand or collapse folders, switch to another section and come back: the scroll position and folders are where you left them. The rows scroll under the pinned dock.")
                    .font(TypographyTokens.callout)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: LayoutTokens.DesignLabRound14.dockCardWidth * 2 + SpacingTokens.lg, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: SpacingTokens.lg) {
                    ForEach(LabDockIconMode.allCases) { mode in
                        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                            Text(mode.rawValue).font(TypographyTokens.headline)
                            LabRound14DockCard(iconMode: mode, labels: labels, edge: edge, animation: speed.spring(reduceMotion: reduceMotion))
                        }
                    }
                }
                .padding(SpacingTokens.md)
                .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
            }
            .padding(SpacingTokens.md)
        }
    }
}
