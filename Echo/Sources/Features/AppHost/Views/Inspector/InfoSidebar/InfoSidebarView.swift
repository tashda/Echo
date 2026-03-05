import SwiftUI

struct InfoSidebarView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appearanceStore: AppearanceStore

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

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .dataInspector:
                        dataInspectorContent
                    case .connection:
                        connectionInspectorContent
                    }
                }
                .padding(.horizontal, InspectorLayout.horizontalPadding)
                .padding(.vertical, SpacingTokens.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        } else if selectedTab == .dataInspector {
            selectedTab = .connection
        }
    }

    @ViewBuilder
    private var dataInspectorContent: some View {
        if let content = environmentState.dataInspectorContent {
            VStack(alignment: .leading, spacing: 16) {
                switch content {
                case .foreignKey(let foreignKeyContent):
                    InspectorPanelView(content: foreignKeyContent, depth: 0)
                    if !projectStore.globalSettings.foreignKeyIncludeRelated {
                        Text("Enable related foreign keys in Settings › Query Results to automatically expand referenced rows when available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, SpacingTokens.xxs)
                    }
                case .json(let jsonContent):
                    JsonInspectorPanelView(content: jsonContent)
                }
            }
        } else {
            InspectorEmptyState(
                title: "No Selection",
                message: "Select a cell to inspect its related data."
            )
        }
    }

    @ViewBuilder
    private var connectionInspectorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let connection = connectionStore.selectedConnection {
                let connectionFields: [ForeignKeyInspectorContent.Field] = [
                    .init(label: "Name", value: connection.connectionName),
                    .init(label: "Host", value: connection.host),
                    .init(label: "User", value: connection.username),
                    .init(label: "Database", value: connection.database.isEmpty ? "Not selected" : connection.database)
                ]
                let connectionContent = ForeignKeyInspectorContent(
                    title: "Connection",
                    subtitle: connection.databaseType.displayName,
                    fields: connectionFields
                )
                InspectorPanelView(content: connectionContent, depth: 0)
            } else {
                InspectorEmptyState(
                    title: "No Connection",
                    message: "Connect to a server to view connection details."
                )
            }

            if let session = environmentState.sessionCoordinator.activeSession {
                let sessionFields: [ForeignKeyInspectorContent.Field] = [
                    .init(label: "Active Database", value: session.selectedDatabaseName ?? "None"),
                    .init(
                        label: "Last Activity",
                        value: session.lastActivity.formatted(date: .abbreviated, time: .shortened)
                    )
                ]
                let sessionContent = ForeignKeyInspectorContent(
                    title: "Session",
                    subtitle: session.connection.connectionName,
                    fields: sessionFields
                )
                InspectorPanelView(content: sessionContent, depth: 0)
            }
        }
    }
}
