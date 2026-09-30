import SwiftUI

/// Wraps tab content with the universal bottom panel (TT1): the content and the panel are cards
/// one gutter apart, and the status bar floats on the canvas below them.
struct TabContentWithPanel<MainContent: View, PanelContent: View>: View {
    @Bindable var panelState: BottomPanelState
    let statusBarConfiguration: BottomPanelStatusBarConfiguration
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let panelContent: () -> PanelContent

    @Environment(ProjectStore.self) private var projectStore

    private let minRatio: CGFloat = 0.2
    private let maxRatio: CGFloat = 0.85

    var body: some View {
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            CardSplitView(
                axis: .vertical,
                fraction: Binding(
                    get: { clampedRatio(panelState.splitRatio) },
                    set: { panelState.splitRatio = clampedRatio($0) }
                ),
                minFraction: minRatio,
                maxFraction: maxRatio,
                showsSecond: panelState.isOpen
            ) {
                mainContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } second: {
                panelContent()
                    .clipped()
            }

            BottomPanelStatusBar(configuration: statusBarConfiguration)
        }
    }

    private func clampedRatio(_ ratio: CGFloat) -> CGFloat {
        min(max(ratio, minRatio), maxRatio)
    }
}
