import SwiftUI

/// A tool tab on the canvas: the shared header (TT2), then the tool on its card, or on cards of
/// its own when its panes are cards (TT1).
struct ToolTabContainer<Content: View>: View {
    let tab: WorkspaceTab
    @ViewBuilder let content: () -> Content

    @Environment(ProjectStore.self) private var projectStore

    private var subtitle: Text {
        let server = tab.connection.connectionName
        if let database = tab.activeDatabaseName, !database.isEmpty { return Text("\(server) · \(database)") }
        return Text(server)
    }

    var body: some View {
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            ToolTabHeader(systemImage: tab.kind.icon, tint: ColorTokens.accent, title: tab.title, subtitle: subtitle)
            content()
                .adaptiveWorkspaceCard()
        }
    }
}
