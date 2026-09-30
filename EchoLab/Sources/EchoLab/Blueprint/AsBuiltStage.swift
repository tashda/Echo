import SwiftUI

/// The stage a specimen sits on, with the shared testing controls (`LabStageControlBar`).
struct AsBuiltStage: View {
    let page: AsBuiltPage
    @State private var settings = LabStageSettings()

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            LabStageControlBar(settings: settings)
            page.specimen()
                .labStage(settings)
                .frame(maxWidth: .infinity)
                .frame(height: page.stageHeight)
                .background(ColorTokens.Workspace.canvas)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.5), lineWidth: 0.5))
                .preferredColorScheme(settings.appearance.scheme)
            if let controls = page.controls {
                controls()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
