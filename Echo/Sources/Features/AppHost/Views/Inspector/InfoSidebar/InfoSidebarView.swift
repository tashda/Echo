import SwiftUI

/// The inspector's content (plan I2): the details of what you pointed at, as a column of cards.
/// Notifications moved to the toolbar bell (plan N3).
struct InfoSidebarView: View {
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        switch environmentState.dataInspectorContent {
        case .databaseObject(let objectContent):
            InspectorPanelView(content: objectContent, depth: 0)
        case .foreignKey(let foreignKeyContent):
            InspectorPanelView(content: foreignKeyContent, depth: 0, systemImage: "link")
        case .json(let jsonContent):
            JsonInspectorPanelView(content: jsonContent)
        case .jobHistory(let historyContent):
            JobHistoryInspectorPanel(content: historyContent)
        case .cellValue(let cellContent):
            CellValueInspectorPanel(content: cellContent)
        case .sqlHelp(let helpContent):
            SQLHelpInspectorPanel(content: helpContent)
        case nil:
            InspectorCard(title: "No Selection", systemImage: "sidebar.right") {
                Text("Select an object, a cell or a row to inspect its details.")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
