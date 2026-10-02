import SwiftUI

/// A tool tab on the canvas: the shared header (TT2) on one line with the controls the tool sets
/// (`toolTabHeaderControls`, round 37.2), then the tool on its card, or on cards of its own when
/// its panes are cards (TT1).
struct ToolTabContainer<Content: View>: View {
    let tab: WorkspaceTab
    @ViewBuilder let content: () -> Content

    @Environment(ProjectStore.self) private var projectStore

    private func subtitle(detail: String?) -> Text {
        var parts = [tab.connection.connectionName]
        if let database = tab.activeDatabaseName, !database.isEmpty { parts.append(database) }
        if let detail, !detail.isEmpty { parts.append(detail) }
        return Text(parts.joined(separator: " · "))
    }

    var body: some View {
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            // The header is drawn over this space from what the tool sets inside its content.
            Color.clear.frame(height: LayoutTokens.ToolTab.headerHeight)
            content()
                .adaptiveWorkspaceCard()
        }
        .overlayPreferenceValue(ToolTabHeaderContentKey.self, alignment: .top) { header in
            ToolTabHeader(systemImage: tab.iconName, tint: ColorTokens.accent, title: tab.title,
                          subtitle: subtitle(detail: header.detail)) {
                header.controls
            }
        }
    }
}
