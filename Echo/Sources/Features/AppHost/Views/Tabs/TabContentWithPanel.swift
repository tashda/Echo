import SwiftUI

/// Wraps any tab content with a universal bottom panel (status bar + toggleable content area).
struct TabContentWithPanel<MainContent: View, PanelContent: View>: View {
    @Bindable var panelState: BottomPanelState
    let statusBarConfiguration: BottomPanelStatusBarConfiguration
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let panelContent: () -> PanelContent

    private let minRatio: CGFloat = 0.2
    private let maxRatio: CGFloat = 0.85

    @State private var liveSplitOverride: CGFloat?
    @State private var lastResizeTimestamp: CFTimeInterval = 0

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let handleHeight: CGFloat = panelState.isOpen ? 9 : 0
            let statusBarHeight: CGFloat = 24
            let splitHeight = totalHeight - handleHeight - statusBarHeight
            let baseRatio = clampedRatio(panelState.splitRatio)
            let effectiveRatio = clampedRatio(liveSplitOverride ?? baseRatio)

            VStack(spacing: 0) {
                mainContent()
                    .frame(height: panelState.isOpen ? splitHeight * effectiveRatio : totalHeight - statusBarHeight)

                if panelState.isOpen {
                    ResizeHandle(
                        ratio: effectiveRatio,
                        minRatio: minRatio,
                        maxRatio: maxRatio,
                        availableHeight: splitHeight,
                        onLiveUpdate: { proposed in
                            let now = CACurrentMediaTime()
                            guard now - lastResizeTimestamp >= 0.016 else { return }
                            lastResizeTimestamp = now
                            liveSplitOverride = proposed
                        },
                        onCommit: { proposed in
                            let clamped = clampedRatio(proposed)
                            liveSplitOverride = nil
                            panelState.splitRatio = clamped
                        }
                    )

                    panelContent()
                        .frame(maxHeight: .infinity)
                        .clipped()
                }

                BottomPanelStatusBar(configuration: statusBarConfiguration)
            }
            .transaction { $0.disablesAnimations = true }
        }
        .background(ColorTokens.Background.primary)
    }

    private func clampedRatio(_ ratio: CGFloat) -> CGFloat {
        min(max(ratio, minRatio), maxRatio)
    }
}
