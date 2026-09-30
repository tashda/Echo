import SwiftUI

/// A tool tab's content with the universal bottom panel (TT1). The same cards as the query
/// tab's editor and results: the panel grows out of the status bar and folds back into it, the
/// gap resizes, and a double-click on it maximises the panel, leaving a one-line content card.
struct TabContentWithPanel<MainContent: View, PanelContent: View>: View {
    @Bindable var panelState: BottomPanelState
    let statusBarConfiguration: BottomPanelStatusBarConfiguration
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let panelContent: () -> PanelContent

    private let minRatio: CGFloat = 0.2
    private let maxRatio: CGFloat = 0.85

    var body: some View {
        ContentPanelCards(
            panelState: panelState,
            minContentFraction: minRatio,
            maxContentFraction: maxRatio
        ) {
            mainContent()
        } panel: {
            panelContent()
        } footer: {
            BottomPanelStatusBar(configuration: statusBarConfiguration)
        }
    }
}
