import SwiftUI

/// The inspector's content (plan I2): the details of what you pointed at, as grouped sections in
/// one card (round 15, "Grouped boxes").
struct InfoSidebarView: View {
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        Group {
            if environmentState.dataInspectorContent == nil {
                emptyState
            } else {
                ScrollView {
                    content
                        .padding(LayoutTokens.Inspector.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    /// Round 32, EI2: centred with a symbol, like the system's empty views.
    private var emptyState: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: "sidebar.right")
                .font(TypographyTokens.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Selection")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Select an object, a cell or a row.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            EmptyView()
        }
    }
}
