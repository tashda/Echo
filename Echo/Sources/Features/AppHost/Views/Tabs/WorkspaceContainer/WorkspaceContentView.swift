import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

struct WorkspaceContentView: View {
    @Bindable var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let gridStateProvider: () -> QueryResultsGridState
    @Environment(AppearanceStore.self) private var appearanceStore

    var body: some View {
        ZStack {
            ColorTokens.Background.primary
                .ignoresSafeArea()

            Group {
                if let structureEditor = tab.structureEditor {
                    TableStructureEditorView(tab: tab, viewModel: structureEditor)
                        .background(ColorTokens.Background.primary)
                } else if let diagram = tab.diagram {
                    SchemaDiagramView(viewModel: diagram)
                        .background(ColorTokens.Background.primary)
                } else if let jobs = tab.jobQueue {
                    JobQueueView(viewModel: jobs)
                        .background(ColorTokens.Background.primary)
                } else if let psql = tab.psql {
                    PSQLTabView(viewModel: psql)
                        .background(ColorTokens.Background.primary)
                } else if let extStructure = tab.extensionStructure {
                    PostgresExtensionStructureView(tab: tab, viewModel: extStructure)
                        .background(ColorTokens.Background.primary)
                } else if let extensionsManager = tab.extensionsManager {
                    PostgresExtensionsView(tab: tab, viewModel: extensionsManager)
                        .background(ColorTokens.Background.primary)
                } else if let activityMonitor = tab.activityMonitor {
                    ActivityMonitorView(viewModel: activityMonitor)
                        .background(ColorTokens.Background.primary)
                } else if tab.maintenance != nil {
                    MaintenanceView(tab: tab)
                        .background(ColorTokens.Background.primary)
                } else if tab.mssqlMaintenance != nil {
                    MaintenanceView(tab: tab)
                        .background(ColorTokens.Background.primary)
                } else if let queryStoreVM = tab.queryStoreVM {
                    QueryStoreView(viewModel: queryStoreVM)
                        .background(ColorTokens.Background.primary)
                } else if let xeVM = tab.extendedEventsVM {
                    ExtendedEventsView(viewModel: xeVM, panelState: tab.panelState)
                        .background(ColorTokens.Background.primary)
                } else if let agVM = tab.availabilityGroupsVM {
                    AvailabilityGroupsView(viewModel: agVM)
                        .background(ColorTokens.Background.primary)
                } else if tab.databaseSecurity != nil {
                    DatabaseSecurityView(tab: tab)
                        .background(ColorTokens.Background.primary)
                } else if tab.serverSecurity != nil {
                    ServerSecurityView(tab: tab)
                        .background(ColorTokens.Background.primary)
                } else if let query = tab.query {
                    QueryEditorContainer(
                        tab: tab,
                        query: query,
                        runQuery: runQuery,
                        gridStateProvider: gridStateProvider
                    )
                } else {
                    EmptyView()
                }
            }
        }
    }
}
