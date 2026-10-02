import SwiftUI

/// The inspector as a column on the canvas (plan I1, round 10 IN1): the tree's mirror on the
/// trailing side, with its resize edge in the gutter before it and the tree's show/hide motion.
/// Round IC: four pages (Details, Bookmarks, History, Notifications) switched by the page strip,
/// which sits on the tab strip's line; the page's card follows one gutter below, as the tab's
/// cards follow the tabs. JSON widens Details with one spring and it returns to the chosen width
/// after (I3).
struct WorkspaceInspectorColumn: View {
    let gutter: CGFloat

    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.echoMotion) private var motion

    @AppStorage("workspace.inspectorWidth") private var chosenWidth = Double(LayoutTokens.Inspector.idealWidth)

    var body: some View {
        let isVisible = appState.isInspectorColumnVisible
        let page = appState.inspectorPage
        let width = Self.displayedWidth(
            chosen: chosenWidth,
            isJson: page == .details && environmentState.dataInspectorContent?.isJson == true
        )

        HStack(spacing: SpacingTokens.none) {
            WorkspaceColumnResizeHandle(
                width: $chosenWidth,
                gutter: gutter,
                range: Double(LayoutTokens.Inspector.minWidth)...Double(LayoutTokens.Inspector.maxWidth),
                defaultWidth: Double(LayoutTokens.Inspector.idealWidth),
                edge: .leading,
                accessibilityLabel: "Inspector width"
            )
            .allowsHitTesting(isVisible)

            VStack(spacing: gutter) {
                InspectorPageStrip()
                ZStack {
                    pageContent(page)
                        .id(page)
                        .transition(.opacity)
                }
            }
            .frame(width: width)
            // The window edge gets a gutter too, as the tree has on the rail's side.
            .padding(.trailing, gutter)
            .accessibilityIdentifier("workspace-inspector")
        }
        // Hidden, it slides out past the trailing edge and fades, exactly like the tree: the shell
        // animates this and the cards' padding in one transaction. Reduce Motion fades only.
        .offset(x: isVisible || motion.reduceMotion ? 0 : width + gutter * 2)
        .opacity(isVisible ? 1 : 0)
        .frame(width: isVisible ? width + gutter * 2 : 0, alignment: .leading)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .animation(motion.pageFade, value: page)
        .animation(motion.standard, value: width)
    }

    @ViewBuilder
    private func pageContent(_ page: InspectorPage) -> some View {
        switch page {
        case .details:
            InfoSidebarView()
        case .bookmarks:
            BookmarksInspectorPage().workspaceCard()
        case .history:
            QueryHistoryPanelView(connectionID: nil).workspaceCard()
        case .notifications:
            if let history = environmentState.notificationEngine?.history {
                NotificationHistoryPanel(history: history)
            } else {
                Color.clear.workspaceCard()
            }
        }
    }

    /// The width on screen: the chosen width, widened for JSON (never narrowed).
    static func displayedWidth(chosen: Double, isJson: Bool) -> CGFloat {
        let clamped = min(max(CGFloat(chosen), LayoutTokens.Inspector.minWidth), LayoutTokens.Inspector.maxWidth)
        return isJson ? max(clamped, LayoutTokens.Inspector.jsonWidth) : clamped
    }
}
