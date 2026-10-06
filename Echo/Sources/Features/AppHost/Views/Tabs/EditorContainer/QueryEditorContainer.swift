import SwiftUI
import EchoSense

struct QueryEditorContainer: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var query: QueryEditorState
    let runQuery: (String) async -> Void
    let gridStateProvider: () -> QueryResultsGridState

    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) var connectionStore
    @Environment(NavigationStore.self) var navigationStore
    @Environment(AppearanceStore.self) var appearanceStore
    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState

    let minRatio: CGFloat = 0.25
    let maxRatio: CGFloat = 0.8
#if os(macOS)
    @State var latestForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
    @State var latestJsonSelection: QueryResultsTableView.JsonSelection?
    @State var foreignKeyFetchTask: Task<Void, Never>?
    /// True when the inspector was auto-opened (by any handler), not manually by the user.
    @State var inspectorAutoOpened = false
#endif

    private var panelState: BottomPanelState { tab.panelState }

    var body: some View {
        // Two cards, editor over results (plan E1–E3). The editor keeps its place in the view
        // tree when results open and close, so it's never rebuilt.
        ContentPanelCards(
            panelState: panelState,
            isPanelOnly: query.isResultsOnly,
            minContentFraction: minRatio,
            maxContentFraction: maxRatio,
            softensUnderFooter: true
        ) {
            VStack(spacing: SpacingTokens.none) {
                if tab.isDedicatedSessionFailed {
                    ConnectionFailedBanner(
                        message: tab.dedicatedSessionError ?? "Connection failed"
                    ) {
                        environmentState.retryDedicatedSession(for: tab)
                    }
                }
                QueryInputSection(
                    query: query,
                    onAddBookmark: handleBookmarkRequest,
                    completionContext: editorCompletionContext,
                    onSchemaLoadNeeded: { dbName in
                        ensureSchemaLoaded(forDatabase: dbName)
                    },
                    onRunStatement: runStatementAtCaret
                )
                .perfSwitch("editor")
            }
        } panel: {
            resultsSection(isResizingResults: false).perfSwitch("results")
        } footer: {
            queryStatusBar.perfSwitch("footer")
        }
        .onAppear {
            updateClipboardContext()
            wireToolbarActions()
        }
        .onChange(of: tab.connection.metadataColorHex) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: tab.connection.database) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: tab.activeDatabaseName) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: query.hasExecutedAtLeastOnce) { _, executed in
            // The results card rises after the first run (plan E2); the cards animate it.
            if executed && !panelState.isOpen && projectStore.globalSettings.autoOpenBottomPanel {
                panelState.isOpen = true
            }
        }
        .task(id: tab.id) {
            wireToolbarActions()
            await ensureCurrentDatabaseSchemaLoaded()
            await triggerAutoExecutionIfNeeded()
        }
        .task(id: connectionDatabaseName ?? tab.connection.database) {
            await ensureCurrentDatabaseSchemaLoaded()
        }
        .onChange(of: connectionSession?.structureLoadingState) {
            Task { await ensureCurrentDatabaseSchemaLoaded() }
        }
        .onChange(of: query.shouldAutoExecuteOnAppear) { _, newValue in
            guard newValue else { return }
            Task {
                await triggerAutoExecutionIfNeeded()
            }
        }
    }

    @MainActor
    private func triggerAutoExecutionIfNeeded() async {
        guard query.shouldAutoExecuteOnAppear else { return }
        guard !query.isExecuting else { return }
        query.shouldAutoExecuteOnAppear = false
        await runQuery(query.sql)
    }

    func wireToolbarActions() {
        tab.executeQueryAction = { [runQuery] sql in
            await runQuery(sql)
        }
    }

    func handleCellInspect(_ content: CellValueInspectorContent) {
        environmentState.dataInspectorContent = .cellValue(content)
        // A double-clicked cell asks for its value (round IC): an open column goes to Details; a
        // closed one opens on Details when auto-open is on.
        if appState.isInspectorVisible {
            appState.showInspectorPage(.details)
        } else if appState.noteDetailsChanged(autoOpen: autoOpenInspector) {
            inspectorAutoOpened = true
        }
    }

    @ViewBuilder
    private func resultsSection(isResizingResults: Bool) -> some View {
#if os(macOS)
        QueryResultsSection(
            query: query,
            connection: connectionForDisplay,
            activeDatabaseName: connectionDatabaseName,
            gridState: gridStateProvider(),
            isResizingResults: isResizingResults,
            panelState: panelState,
            onForeignKeyEvent: handleForeignKeyEvent,
            onJsonEvent: handleJsonEvent,
            onCellInspect: handleCellInspect
        )
#else
        QueryResultsSection(
            query: query,
            connection: connectionForDisplay,
            activeDatabaseName: connectionDatabaseName,
            gridState: gridStateProvider(),
            isResizingResults: isResizingResults,
            panelState: panelState
        )
#endif
    }

    private var queryStatusBar: some View {
        QueryPanelStatusBar(
            query: query,
            panelState: panelState,
            serverName: connectionServerName ?? "Server",
            databaseName: connectionDatabaseName,
            availableDatabases: resolveDatabaseNames(),
            onSwitchDatabase: tab.connection.databaseType == .sqlite ? nil : { dbName in
                switchDatabase(dbName)
            },
            onRunCommand: { [runQuery, query] sql in
                query.lastRunRange = nil
                Task { await runQuery(sql) }
            },
            serverMove: connectionSession?.serverMove
        )
    }

    private func resolveDatabaseNames() -> [String] {
        environmentState.switchableDatabaseNames(for: tab)
    }

    private func switchDatabase(_ databaseName: String) {
        environmentState.switchDatabase(databaseName, for: tab)
    }
}
