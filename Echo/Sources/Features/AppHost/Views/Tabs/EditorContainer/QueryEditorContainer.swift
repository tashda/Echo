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
    @State var liveSplitRatioOverride: CGFloat?
    @State private var lastResizeTimestamp: CFTimeInterval = 0
#if os(macOS)
    @State var latestForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
    @State var latestJsonSelection: QueryResultsTableView.JsonSelection?
    @State var foreignKeyFetchTask: Task<Void, Never>?
    /// True when the inspector was auto-opened (by any handler), not manually by the user.
    @State var inspectorAutoOpened = false
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
            let handleHeight: CGFloat = query.hasExecutedAtLeastOnce ? 9 : 0
            let splitHeight = totalHeight - handleHeight
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
                    onForeignKeyEvent: handleForeignKeyEvent,
                    onJsonEvent: handleJsonEvent,
                    onCellInspect: handleCellInspect
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
                    let statusBarHeight: CGFloat = 24
                    let editorHeight: CGFloat = query.hasExecutedAtLeastOnce
                        ? splitHeight * effectiveRatio
                        : totalHeight - statusBarHeight

                    QueryInputSection(
                        query: query,
                        onExecute: { sql in await runQuery(sql) },
                        onCancel: cancelQuery,
                        onAddBookmark: handleBookmarkRequest,
                        completionContext: editorCompletionContext
                    )
                    .frame(height: editorHeight)
                    .background(backgroundColor)

                    if query.hasExecutedAtLeastOnce {
                        ResizeHandle(
                            ratio: effectiveRatio,
                            minRatio: minRatio,
                            maxRatio: maxRatio,
                            availableHeight: splitHeight,
                            onLiveUpdate: { proposed in
                                let now = CACurrentMediaTime()
                                guard now - lastResizeTimestamp >= 0.016 else { return }
                                lastResizeTimestamp = now
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
                    }

                #if os(macOS)
                    QueryResultsSection(
                        query: query,
                        connection: connectionForDisplay,
                        activeDatabaseName: connectionDatabaseName,
                        gridState: gridStateProvider(),
                        isResizingResults: isResizingResults,
                        onForeignKeyEvent: handleForeignKeyEvent,
                        onJsonEvent: handleJsonEvent,
                        onCellInspect: handleCellInspect
                    )
                        .frame(maxHeight: .infinity)
                        .clipped()
                        .background(backgroundColor)
                #else
                    QueryResultsSection(
                        query: query,
                        connection: connectionForDisplay,
                        activeDatabaseName: connectionDatabaseName,
                        gridState: gridStateProvider(),
                        isResizingResults: isResizingResults
                    )
                        .frame(maxHeight: .infinity)
                        .clipped()
                        .background(backgroundColor)
                #endif
                }
            }
            .transaction { $0.disablesAnimations = true }
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

}
