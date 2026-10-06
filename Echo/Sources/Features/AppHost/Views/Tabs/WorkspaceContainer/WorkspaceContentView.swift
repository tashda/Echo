import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#endif

struct WorkspaceContentView: View, Equatable {
    @Bindable var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let gridStateProvider: () -> QueryResultsGridState
    
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearanceStore
    
    /// Same tab, same content: the closures `runQuery` and `gridStateProvider` are made anew by
    /// every parent evaluation but always do the same for this tab, so they are left out.
    nonisolated static func == (lhs: WorkspaceContentView, rhs: WorkspaceContentView) -> Bool {
        MainActor.assumeIsolated { lhs.tab === rhs.tab }
    }

    @State private var selectedSQLContext: SQLPopoutContext?
    @Environment(\.keptAliveTabsActivity) private var tabsActivity
    @Environment(\.keptAliveTabID) private var tabID

    var body: some View {
        ZStack {
            // Query tabs draw their own cards on the canvas, so nothing fills behind them.
            if !tab.drawsOwnCards {
                ColorTokens.Background.primary
                    .ignoresSafeArea()
            }

            tabContentView
        }
        .environment(\.workspaceTab, tab)
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorSheet(context: context) { sql, database in
                if let session = environmentState.sessionGroup.sessionForConnection(tab.connection.id) {
                    environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
                } else {
                    environmentState.openQueryTab(presetQuery: sql, database: database)
                }
            }
        }
        // The tab presents only its own sheet (the structure script preview), and only while it is
        // on screen: every kept-mounted tab carries this modifier, and the window presents the
        // other sheets (connection editor, Quick Connect) itself.
        .sheet(
            item: Binding<ActiveSheet?>(
                get: {
                    guard appState.activeSheet == .structureScriptPreview,
                          KeptAliveTabsActivity.isActive(tabID, in: tabsActivity) else { return nil }
                    return appState.activeSheet
                },
                set: { newValue in
                    if let newValue {
                        appState.activeSheet = newValue
                    } else {
                        appState.dismissSheet()
                    }
                }
            )
        ) { sheet in
            switch sheet {
            case .structureScriptPreview:
                if let data = appState.structureScriptData {
                    StructureScriptPreviewSheet(
                        context: SQLPopoutContext(
                            sql: data.statements.joined(separator: "\n\n"),
                            title: "Script Preview"
                        )
                    ) { sql, database in
                        if let session = environmentState.sessionGroup.sessionForConnection(tab.connection.id) {
                            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
                        } else {
                            environmentState.openQueryTab(presetQuery: sql, database: database)
                        }
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Content Resolution (switch-based to help type-checker)

    @ViewBuilder
    private var tabContentView: some View {
        switch tab.kind {
        case .structure:
            if let vm = tab.structureEditor {
                ZStack {
                    TableStructureEditorView(tab: tab, viewModel: vm)
                        .background(ColorTokens.Background.primary)
                    TableStructureSheetHost(tab: tab, viewModel: vm)
                }
            }
        case .diagram:
            if let vm = tab.diagram {
                SchemaDiagramView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .jobQueue:
            if let vm = tab.jobQueue {
                JobQueueView(viewModel: vm)
            }
        case .psql:
            if let vm = tab.psql {
                PSQLTabView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .extensionStructure:
            if let vm = tab.extensionStructure {
                PostgresExtensionStructureView(tab: tab, viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .extensionsManager:
            if let vm = tab.extensionsManager {
                PostgresExtensionsView(tab: tab, viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .activityMonitor:
            if let vm = tab.activityMonitor {
                ActivityMonitorView(viewModel: vm)
            }
        case .maintenance, .mssqlMaintenance:
            MaintenanceView(tab: tab).background(ColorTokens.Background.primary)
        case .extendedEvents:
            if let vm = tab.extendedEventsVM {
                ExtendedEventsView(viewModel: vm, panelState: tab.panelState)
                    .background(ColorTokens.Background.primary)
            }
        case .availabilityGroups:
            if let vm = tab.availabilityGroupsVM {
                AvailabilityGroupsView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .databaseSecurity:
            DatabaseSecurityView(tab: tab).background(ColorTokens.Background.primary)
        case .postgresSecurity:
            if let vm = tab.postgresSecurity {
                PostgresDatabaseSecurityView(viewModel: vm, panelState: tab.panelState).background(ColorTokens.Background.primary)
            }
        case .mysqlSecurity:
            if let vm = tab.mysqlSecurity {
                MySQLDatabaseSecurityView(viewModel: vm, panelState: tab.panelState).background(ColorTokens.Background.primary)
            }
        case .postgresAdvancedObjects:
            if let vm = tab.postgresAdvancedObjectsVM {
                PostgresAdvancedObjectsView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .mssqlAdvancedObjects:
            if let vm = tab.mssqlAdvancedObjectsVM {
                MSSQLAdvancedObjectsView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .schemaDiff:
            if let vm = tab.schemaDiffVM {
                SchemaDiffView(viewModel: vm, panelState: tab.panelState)
                    .background(ColorTokens.Background.primary)
            }
        case .queryBuilder:
            if let vm = tab.queryBuilderVM {
                VisualQueryBuilderView(viewModel: vm)
                    .background(ColorTokens.Background.primary)
            }
        case .serverSecurity:
            ServerSecurityView(tab: tab).background(ColorTokens.Background.primary)
        case .errorLog:
            if let vm = tab.errorLogVM {
                ErrorLogView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .profiler:
            if let vm = tab.profilerVM {
                ProfilerView(
                    viewModel: vm,
                    onPopout: { sql in selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details", dialect: .microsoftSQL) },
                    onDoubleClick: { appState.showInfoSidebar.toggle() }
                ).background(ColorTokens.Background.primary)
            }
        case .resourceGovernor:
            if let vm = tab.resourceGovernorVM {
                ResourceGovernorView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .tuningAdvisor:
            if let vm = tab.tuningAdvisorVM {
                TuningAdvisorView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .policyManagement:
            if let vm = tab.policyManagementVM {
                PolicyManagementView(viewModel: vm).background(ColorTokens.Background.primary)
            }
        case .serverProperties:
            if let vm = tab.serverPropertiesVM {
                ServerPropertiesView(viewModel: vm, panelState: tab.panelState).background(ColorTokens.Background.primary)
            }
        case .query:
            if let query = tab.query {
                QueryEditorContainer(tab: tab, query: query, runQuery: runQuery, gridStateProvider: gridStateProvider)
            }
        }
    }
}
