import SwiftUI

struct InfoSidebarView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore

    @State private var selectedTab: InspectorTab = .dataInspector

    private var hasDataInspectorContent: Bool {
        environmentState.dataInspectorContent != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabSelector(selectedTab: $selectedTab)
                .padding(.horizontal, InspectorLayout.horizontalPadding)
                .padding(.top, 0)
                .padding(.bottom, SpacingTokens.xs)

            Divider()
                .opacity(0.08)

            switch selectedTab {
            case .dataInspector:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        dataInspectorContent
                    }
                    .padding(.horizontal, InspectorLayout.horizontalPadding)
                    .padding(.vertical, SpacingTokens.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .notifications:
                NotificationInspectorView(
                    notificationEngine: environmentState.notificationEngine
                )
            }
        }
        .onAppear(perform: updateSelectionForAvailableContent)
        .onChange(of: environmentState.dataInspectorContent) { _, _ in
            updateSelectionForAvailableContent()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func updateSelectionForAvailableContent() {
        if hasDataInspectorContent {
            selectedTab = .dataInspector
        }
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
