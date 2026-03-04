import SwiftUI
import EchoSense

struct QueryEditorContainer: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var query: QueryEditorState
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    let gridStateProvider: () -> QueryResultsGridState
    
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @EnvironmentObject internal var themeManager: ThemeManager
    @EnvironmentObject internal var workspaceSessionStore: WorkspaceSessionStore
    @EnvironmentObject internal var appState: AppState

    internal let minRatio: CGFloat = 0.25
    internal let maxRatio: CGFloat = 0.8
    @State internal var liveSplitRatioOverride: CGFloat?
#if os(macOS)
    @State internal var latestForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
    @State internal var latestJsonSelection: QueryResultsTableView.JsonSelection?
    @State internal var foreignKeyFetchTask: Task<Void, Never>?
    @State internal var autoOpenedInspector = false
#endif

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let backgroundColor = ColorTokens.Background.primary
            let shouldShowResultsOnly = query.isResultsOnly
            let ratioBinding = Binding<CGFloat>(
                get: { min(max(query.splitRatio, minRatio), maxRatio) },
                set: { newValue in
                    query.splitRatio = min(max(newValue, minRatio), maxRatio)
                }
            )
            let baseRatio = ratioBinding.wrappedValue
            let effectiveRatio = min(max(liveSplitRatioOverride ?? baseRatio, minRatio), maxRatio)
            let isResizingResults = liveSplitRatioOverride != nil

            VStack(spacing: 0) {
                if shouldShowResultsOnly {
#if os(macOS)
                QueryResultsSection(
                    query: query,
                    connection: connectionForDisplay,
                    activeDatabaseName: connectionDatabaseName,
                    gridState: gridStateProvider(),
                    isResizingResults: isResizingResults,
                    foreignKeyDisplayMode: foreignKeyDisplayMode,
                    foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                    onForeignKeyEvent: handleForeignKeyEvent,
                    onJsonEvent: handleJsonEvent
                )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(backgroundColor)
                        .transition(.opacity)
                #else
                    QueryResultsSection(
                        query: query,
                        connection: connectionForDisplay,
                        activeDatabaseName: connectionDatabaseName,
                        gridState: gridStateProvider(),
                        isResizingResults: isResizingResults
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(backgroundColor)
                        .transition(.opacity)
                #endif
                } else {
                    QueryInputSection(
                        query: query,
                        onExecute: { sql in await runQuery(sql) },
                        onCancel: cancelQuery,
                        onAddBookmark: handleBookmarkRequest,
                        completionContext: editorCompletionContext
                    )
                    .frame(height: query.hasExecutedAtLeastOnce ? totalHeight * effectiveRatio : totalHeight)
                    .background(backgroundColor)

                    if query.hasExecutedAtLeastOnce {
                        ResizeHandle(
                            ratio: effectiveRatio,
                            minRatio: minRatio,
                            maxRatio: maxRatio,
                            availableHeight: totalHeight,
                            onLiveUpdate: { proposed in
                                liveSplitRatioOverride = proposed
                            },
                            onCommit: { proposed in
                                let clamped = min(max(proposed, minRatio), maxRatio)
                                liveSplitRatioOverride = nil
                                if abs(ratioBinding.wrappedValue - clamped) > 0.0001 {
                                    ratioBinding.wrappedValue = clamped
                                }
                            }
                        )

                    #if os(macOS)
                        QueryResultsSection(
                            query: query,
                            connection: connectionForDisplay,
                            activeDatabaseName: connectionDatabaseName,
                            gridState: gridStateProvider(),
                            isResizingResults: isResizingResults,
                            foreignKeyDisplayMode: foreignKeyDisplayMode,
                            foreignKeyInspectorBehavior: foreignKeyInspectorBehavior,
                            onForeignKeyEvent: handleForeignKeyEvent,
                            onJsonEvent: handleJsonEvent
                        )
                            .frame(height: totalHeight * (1 - effectiveRatio))
                            .background(backgroundColor)
                            .transition(.opacity)
                    #else
                        QueryResultsSection(
                            query: query,
                            connection: connectionForDisplay,
                            activeDatabaseName: connectionDatabaseName,
                            gridState: gridStateProvider(),
                            isResizingResults: isResizingResults
                        )
                            .frame(height: totalHeight * (1 - effectiveRatio))
                            .background(backgroundColor)
                            .transition(.opacity)
                    #endif
                    }
                }
            }
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
        .onChange(of: query.isResultsOnly) { _, _ in
            liveSplitRatioOverride = nil
        }
        .onChange(of: query.hasExecutedAtLeastOnce) { _, executed in
            if !executed {
                liveSplitRatioOverride = nil
            }
        }
        .task {
            await triggerAutoExecutionIfNeeded()
        }
        .onChange(of: query.shouldAutoExecuteOnAppear) { _, newValue in
            guard newValue else { return }
            Task {
                await triggerAutoExecutionIfNeeded()
            }
        }
    }

    internal var connectionSession: ConnectionSession? {
        workspaceSessionStore.sessionManager.activeSessions.first { $0.id == tab.connectionSessionID }
    }

    internal var connectionServerName: String? {
        let name = (connectionSession?.connection.connectionName ?? tab.connection.connectionName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let host = (connectionSession?.connection.host ?? tab.connection.host)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? nil : host
    }

    internal var connectionDatabaseName: String? {
        if let selected = connectionSession?.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty {
            return selected
        }
        let database = tab.connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return database.isEmpty ? nil : database
    }

#if os(macOS)
    internal var foreignKeyDisplayMode: ForeignKeyDisplayMode {
        projectStore.globalSettings.foreignKeyDisplayMode
    }

    internal var foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior {
        projectStore.globalSettings.foreignKeyInspectorBehavior
    }

    internal var includeRelatedForeignKeys: Bool {
        projectStore.globalSettings.foreignKeyIncludeRelated
    }
#endif

    @MainActor
    private func triggerAutoExecutionIfNeeded() async {
        guard query.shouldAutoExecuteOnAppear else { return }
        guard !query.isExecuting else { return }
        query.shouldAutoExecuteOnAppear = false
        await runQuery(query.sql)
    }

    internal func updateClipboardContext() {
        query.updateClipboardContext(
            serverName: connectionServerName,
            databaseName: connectionDatabaseName,
            connectionColorHex: connectionColorHex
        )
    }

    private var connectionServerVersion: String? {
        let candidates: [String?] = [
            connectionSession?.databaseStructure?.serverVersion,
            connectionSession?.connection.serverVersion,
            tab.connection.serverVersion
        ]
        for candidate in candidates {
            if let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    internal var connectionForDisplay: SavedConnection {
        var snapshot = connectionSession?.connection ?? tab.connection
        snapshot.serverVersion = connectionServerVersion
        return snapshot
    }

    internal var connectionColorHex: String? {
        if let sessionHex = connectionSession?.connection.metadataColorHex {
            return sessionHex
        }
        return tab.connection.metadataColorHex
    }

    internal var editorCompletionContext: SQLEditorCompletionContext? {
        let session = connectionSession
        let baseConnection = session?.connection ?? tab.connection
        let databaseType = EchoSenseDatabaseType(baseConnection.databaseType)
        let selectedDatabase = normalized(session?.selectedDatabaseName)
            ?? normalized(baseConnection.database)
        let structure = session?.databaseStructure
            ?? session?.connection.cachedStructure
            ?? tab.connection.cachedStructure
        let defaultSchema = defaultSchema(for: databaseType)

        return SQLEditorCompletionContext(
            databaseType: databaseType,
            selectedDatabase: selectedDatabase,
            defaultSchema: defaultSchema,
            structure: structure.flatMap { EchoSenseBridge.makeStructure(from: $0) }
        )
    }

    private func defaultSchema(for type: EchoSenseDatabaseType) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql, .sqlite:
            return nil
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    internal func handleBookmarkRequest(_ sql: String) {
        Task {
            await workspaceSessionStore.addBookmark(
                for: tab.connection,
                databaseName: connectionDatabaseName,
                title: tabTitleForBookmark,
                query: sql,
                source: .queryEditorSelection
            )
        }
    }

    private var tabTitleForBookmark: String? {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
