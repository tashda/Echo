import SwiftUI

/// Wraps any tab content with a universal bottom panel (status bar + toggleable content area).
struct TabContentWithPanel<MainContent: View, PanelContent: View>: View {
    @Bindable var panelState: BottomPanelState
    let statusBarConfiguration: BottomPanelStatusBarConfiguration
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let panelContent: () -> PanelContent

    private let minRatio: CGFloat = 0.2
    private let maxRatio: CGFloat = 0.85

    var body: some View {
        VStack(spacing: 0) {
            if panelState.isOpen {
                NativeSplitView(
                    isVertical: false,
                    firstMinFraction: minRatio,
                    secondMinFraction: 1 - maxRatio,
                    fraction: Binding(
                        get: { clampedRatio(panelState.splitRatio) },
                        set: { panelState.splitRatio = clampedRatio($0) }
                    )
                ) {
                    mainContent()
                } second: {
                    panelContent()
                        .clipped()
                }
            } else {
                mainContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            BottomPanelStatusBar(configuration: statusBarConfiguration)
        }
        .background(ColorTokens.Background.primary)
    }

    private func clampedRatio(_ ratio: CGFloat) -> CGFloat {
        min(max(ratio, minRatio), maxRatio)
    }
}
