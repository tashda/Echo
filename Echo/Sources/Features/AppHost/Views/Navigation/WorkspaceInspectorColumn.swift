import SwiftUI

/// The inspector as a column of cards on the canvas (plan I1, round 10 IN1): the tree's mirror on
/// the trailing side, with its resize edge in the gutter before it and the tree's show/hide motion.
/// JSON widens it with one spring and it returns to the chosen width after (I3).
struct WorkspaceInspectorColumn: View {
    let gutter: CGFloat

    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.echoMotion) private var motion

    @AppStorage("workspace.inspectorWidth") private var chosenWidth = Double(LayoutTokens.Inspector.idealWidth)

    var body: some View {
        let isVisible = appState.showInfoSidebar
        let width = Self.displayedWidth(
            chosen: chosenWidth,
            isJson: environmentState.dataInspectorContent?.isJson == true
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

            InfoSidebarView()
                .frame(width: width)
                .accessibilityIdentifier("workspace-inspector")
        }
        // Hidden, it slides out past the trailing edge and fades. Reduce Motion fades only.
        .offset(x: isVisible || motion.reduceMotion ? 0 : width + gutter)
        .opacity(isVisible ? 1 : 0)
        .frame(width: isVisible ? width + gutter : 0, alignment: .leading)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .animation(motion.standard, value: isVisible)
        .animation(motion.standard, value: width)
    }

    /// The width on screen: the chosen width, widened for JSON (never narrowed).
    static func displayedWidth(chosen: Double, isJson: Bool) -> CGFloat {
        let clamped = min(max(CGFloat(chosen), LayoutTokens.Inspector.minWidth), LayoutTokens.Inspector.maxWidth)
        return isJson ? max(clamped, LayoutTokens.Inspector.jsonWidth) : clamped
    }
}
