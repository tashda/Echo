import SwiftUI
import EchoSense

struct QueryEditorContainer: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var query: QueryEditorState
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
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
        let backgroundColor = ColorTokens.Background.primary
        let shouldShowResultsOnly = query.isResultsOnly
        let panelOpen = panelState.isOpen

        VStack(spacing: 0) {
            if shouldShowResultsOnly {
                resultsSection(isResizingResults: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                    .transition(.opacity)
            } else if panelOpen {
                NativeSplitView(
                    isVertical: false,
                    firstMinFraction: minRatio,
                    secondMinFraction: 1 - maxRatio,
                    fraction: Binding(
                        get: { min(max(panelState.splitRatio, minRatio), maxRatio) },
                        set: { panelState.splitRatio = min(max($0, minRatio), maxRatio) }
                    )
                ) {
                    QueryInputSection(
                        query: query,
                        onExecute: { sql in await runQuery(sql) },
                        onCancel: cancelQuery,
                        onAddBookmark: handleBookmarkRequest,
                        completionContext: editorCompletionContext,
                        onSchemaLoadNeeded: { dbName in
                            ensureSchemaLoaded(forDatabase: dbName)
                        }
                    )
                    .background(backgroundColor)
                } second: {
                    resultsSection(isResizingResults: false)
                        .clipped()
                        .background(backgroundColor)
                }
            } else {
                QueryInputSection(
                    query: query,
                    onExecute: { sql in await runQuery(sql) },
                    onCancel: cancelQuery,
                    onAddBookmark: handleBookmarkRequest,
                    completionContext: editorCompletionContext,
                    onSchemaLoadNeeded: { dbName in
                        ensureSchemaLoaded(forDatabase: dbName)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundColor)
            }

            queryStatusBar
        }
        .background(ColorTokens.Background.primary)
        .onAppear {
            updateClipboardContext()
        }
        .onChange(of: tab.connection.metadataColorHex) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: tab.connection.database) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: query.hasExecutedAtLeastOnce) { _, executed in
            if executed && !panelState.isOpen && projectStore.globalSettings.autoOpenBottomPanel {
                panelState.isOpen = true
            }
        }
        .task {
            await triggerAutoExecutionIfNeeded()
            ensureCurrentDatabaseStructureLoaded()
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

    func handleCellInspect(_ content: CellValueInspectorContent) {
        environmentState.dataInspectorContent = .cellValue(content)
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
            connectionText: connectionChipText
        )
    }

    private var connectionChipText: String {
        let server = connectionServerName ?? "Server"
        guard let db = connectionDatabaseName else { return server }
        return "\(server) • \(db)"
    }
}
