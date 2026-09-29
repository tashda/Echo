import SwiftUI

struct InfoSidebarView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore

    // Notifications moved to the toolbar bell (plan N3), so the inspector has one job: the
    // details of what you pointed at.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                dataInspectorContent
            }
            .padding(.horizontal, InspectorLayout.horizontalPadding)
            .padding(.vertical, SpacingTokens.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var dataInspectorContent: some View {
        if let content = environmentState.dataInspectorContent {
            VStack(alignment: .leading, spacing: 16) {
                switch content {
                case .databaseObject(let objectContent):
                    InspectorPanelView(content: objectContent, depth: 0)
                case .foreignKey(let foreignKeyContent):
                    InspectorPanelView(content: foreignKeyContent, depth: 0)
                case .json(let jsonContent):
                    JsonInspectorPanelView(content: jsonContent)
                case .jobHistory(let historyContent):
                    JobHistoryInspectorPanel(content: historyContent)
                case .cellValue(let cellContent):
                    CellValueInspectorPanel(content: cellContent)
                case .sqlHelp(let helpContent):
                    SQLHelpInspectorPanel(content: helpContent)
                }
            }
        } else {
            InspectorEmptyState(
                title: "No Selection",
                message: "Select an object to inspect its details."
            )
        }
    }
}
