import Foundation
import SwiftUI
import Observation
import OSLog

@Observable @MainActor final class QueryEditorState {
    var sql: String
    var results: QueryResultSet?
    var errorMessage: String?
    var isExecuting: Bool = false
    /// True while the query tab is establishing its dedicated database connection.
    var isEstablishingConnection: Bool = false
    /// Set when the tab's connection dropped (round 21); the footer then says Disconnected.
    var connectionLoss: QueryConnectionLoss?
    /// True while a cross-database schema is being loaded for autocompletion.
    var isLoadingCrossDBSchema: Bool = false
    /// The database name currently being loaded for cross-DB autocompletion.
    var crossDBSchemaTarget: String?
    /// Incremented each time `startExecution()` runs. Used as a SwiftUI `.id()`
    /// on the result table so that it is fully recreated between query runs.
    var executionGeneration: Int = 0
    var lastExecutionTime: TimeInterval?
    var currentExecutionTime: TimeInterval = 0
    var rowProgress: RowProgress = RowProgress()
    /// The results grid's selected cells, summed for the footer (plan R5).
    var gridSelectionSummary: GridSelectionSummary?
    var messages: [QueryExecutionMessage] = []
    var prefersMessagesAfterExecution: Bool = false
    var hasExecutedAtLeastOnce: Bool = false
    var splitRatio: CGFloat = 0.5
    var wasCancelled: Bool = false
    var visibleRowLimit: Int?
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    var isResultsOnly: Bool = false
    var shouldAutoExecuteOnAppear: Bool = false
    var lastPerformanceReport: QueryPerformanceTracker.Report?
    var livePerformanceReport: QueryPerformanceTracker.Report?
    var streamingModeOverride: ResultStreamingExecutionMode = .auto
    var statisticsEnabled: Bool = false
    var sqlcmdModeEnabled: Bool = false
    /// Incremented to trigger on-demand validation. The text view observes this.
    var validationRequestGeneration: Int = 0
    /// Set to move the editor's caret to a line, as "Show in Editor" on a query error does.
    var editorLineRequest: EditorLineRequest?
    @ObservationIgnored var rowCountRefreshHandler: (() -> Void)?
    var streamingMode: StreamingMode = .idle

    @ObservationIgnored let initialVisibleRowBatch: Int
    @ObservationIgnored let previewRowLimit: Int
    @ObservationIgnored let spoolActivationThreshold: Int
    @ObservationIgnored let spoolManager: ResultSpooler
    @ObservationIgnored var spoolHandle: ResultSpoolHandle?
    @ObservationIgnored var ingestionService: ResultStreamIngestor?
    @ObservationIgnored var spoolStatsTask: Task<Void, Never>?
    var resultSpoolID: UUID?
    @ObservationIgnored var didReceiveStreamingUpdate = false
    @ObservationIgnored let rowCache = ResultSpoolRowCache(pageSize: 512, maxPages: 256)
    @ObservationIgnored let gridViewportForwardPrefetchRows: Int
    @ObservationIgnored let gridViewportBackfillRows: Int
    @ObservationIgnored var lastVisibleDisplayRange: Range<Int> = 0..<0
    @ObservationIgnored var lastPrefetchedSourceRange: Range<Int> = 0..<0
    @ObservationIgnored var pendingVisibleRowReloadIndexes: IndexSet?

    @ObservationIgnored var lastSpoolStatsRowCount: Int = 0
    @ObservationIgnored var hasAppliedFinalSpoolStats: Bool = false

    @ObservationIgnored var lastBroadcastSnapshot: BroadcastSnapshot?
    @ObservationIgnored let payloadFormatter = PostgresPayloadFormatter()

    var gridViewportPadding: Int {
        gridViewportForwardPrefetchRows + gridViewportBackfillRows
    }

    var gridViewportLayoutPadding: Int {
        let forwardContribution = gridViewportForwardPrefetchRows / 2
        let total = forwardContribution + gridViewportBackfillRows
        return min(max(total, 128), 256)
    }

    @ObservationIgnored var streamedRowCount: Int = 0
    @ObservationIgnored let frontBufferLimit: Int
    @ObservationIgnored var deferredSpoolUpdates: [BufferedSpoolUpdate] = []
    @ObservationIgnored var isSpoolActivationDeferred: Bool = true
    @ObservationIgnored var isResultChangeCoalesced: Bool = false

    @ObservationIgnored var executionStartTime: Date?
    @ObservationIgnored var executionTimer: Timer?
    @ObservationIgnored var lastMessageTimestamp: Date?
    @ObservationIgnored var executingTask: Task<Void, Never>?
    @ObservationIgnored var isCancellationRequested: Bool = false
    var streamingColumns: [ColumnInfo] = []
    var streamingRows: [[String?]] = []
    var resultChangeToken: UInt64 = 0
    private(set) var resultsFormattingMode: ResultsFormattingMode = .immediate
    private(set) var resultsTypeFormattingEnabled: Bool = true

    typealias DataPreviewFetcher = @Sendable (_ offset: Int, _ limit: Int) async throws -> QueryResultSet

    @ObservationIgnored var dataPreviewState: DataPreviewState?
    @ObservationIgnored var dataPreviewFetchTask: Task<Void, Never>?
    @ObservationIgnored var performanceTracker: QueryPerformanceTracker
    @ObservationIgnored lazy var formattingCoordinator: ResultRowFormattingCoordinator = {
        ResultRowFormattingCoordinator(
            formatter: PostgresPayloadFormatter()
        ) { [weak self] batch in
            self?.handleFormattedBatch(batch)
        }
    }()
    @ObservationIgnored var formattingGeneration: Int = 0
    @ObservationIgnored var formattingResetTask: Task<Void, Never>?
    @ObservationIgnored var materializedHighWaterMark: Int = 0
    @ObservationIgnored let rowDiagnosticsEnabled = ProcessInfo.processInfo.environment["ECHO_ROW_DEBUG"] == "1"
    @ObservationIgnored var hasAnnouncedRowDiagnostics = false

    typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]
    @ObservationIgnored var foreignKeyContext: ForeignKeyResolutionContext?
    @ObservationIgnored var cachedForeignKeyMapping: ForeignKeyMapping = [:]
    @ObservationIgnored var hasLoadedForeignKeyMapping = false
    @ObservationIgnored var isLoadingForeignKeyMapping = false
    @ObservationIgnored var shouldPersistResults = false
    @ObservationIgnored var progressiveMaterializationTask: Task<Void, Never>?
    @ObservationIgnored var deferredEnqueueTask: Task<Void, Never>?
    var additionalResults: [QueryResultSet] = [] {
        didSet { additionalResultStates.removeAll() }
    }
    /// Results-only states for the extra result sets, made on first view (plan R6).
    @ObservationIgnored var additionalResultStates: [Int: QueryEditorState] = [:]
    var selectedResultSetIndex: Int = 0
    /// Batch labels for multi-batch (GO) results. Nil for single-batch execution.
    var batchResultMetadata: [BatchResultLabel]?
    /// A PostgreSQL script's statements, for the statement list (round 21, script results).
    var scriptEntries: [ScriptResultEntry]?
    /// The statement selected in the list; its statement is highlighted in the editor (SK2).
    var selectedScriptEntryID: Int?
    /// The editor range of the selected statement, drawn as a band until the text changes.
    var highlightedStatementRange: NSRange?
    /// Query › Run as One Transaction (round 21, OT1): off by default, per tab.
    var runsScriptAsOneTransaction = false
    var executionPlan: ExecutionPlanData?
    var isLoadingExecutionPlan: Bool = false
    var dataClassification: DataClassification?

    // MARK: - Selection State (observed by toolbar)

    /// True when the user has a non-empty text selection in the editor.
    var hasActiveSelection: Bool = false
    /// The selected text, available for "Run Selection".
    @ObservationIgnored var selectedText: String = ""
    /// The caret's UTF-16 offset, for Run Statement at Cursor (plan K1).
    @ObservationIgnored var caretLocation: Int = 0
    /// The selected range, for placing the note after Run Selection (QE2).
    @ObservationIgnored var selectionRange = NSRange(location: 0, length: 0)
    /// What the last run covered, and the note shown at its end once it finishes (QE2).
    @ObservationIgnored var lastRunRange: NSRange?
    var runNote: QueryRunNote?

    // MARK: - Debug Session State

    var debugMode: Bool = false
    var debugStatements: [TSQLStatementSplitter.Statement] = []
    var debugCurrentIndex: Int = 0
    var debugPhase: DebugPhase = .idle
    var debugVariables: [DebugVariable] = []
    var debugBreakpoints: Set<DebugBreakpoint> = []
    @ObservationIgnored var debugContinuation: CheckedContinuation<Void, Never>?

    init(
        sql: String = "",
        initialVisibleRowBatch: Int = 500,
        previewRowLimit: Int = 512,
        spoolManager: ResultSpooler,
        backgroundFetchSize: Int = 4_096
    ) {
        self.sql = sql
        let normalizedInitial = max(100, initialVisibleRowBatch)
        let normalizedPreview = max(normalizedInitial, previewRowLimit)
        let normalizedFetchSize = max(128, min(backgroundFetchSize, 16_384))
        self.initialVisibleRowBatch = normalizedInitial
        self.previewRowLimit = normalizedPreview
        self.spoolManager = spoolManager
        self.performanceTracker = QueryPerformanceTracker(initialBatchTarget: self.initialVisibleRowBatch)
        let spoolThresholdCandidate = max(normalizedInitial * 4, 1_024)
        let activationCap = max(normalizedPreview, 8_192)
        let resolvedActivation = min(max(normalizedPreview, spoolThresholdCandidate), activationCap)
        self.spoolActivationThreshold = resolvedActivation
        self.frontBufferLimit = self.initialVisibleRowBatch
        self.gridViewportForwardPrefetchRows = max(normalizedFetchSize * 2, self.previewRowLimit)
        self.gridViewportBackfillRows = max(self.initialVisibleRowBatch / 2, 128)
    }

    @MainActor deinit {
        dataPreviewFetchTask?.cancel()
        spoolStatsTask?.cancel()
        progressiveMaterializationTask?.cancel()
        guard let identifier = resultSpoolID else { return }
        let manager = spoolManager
        Task.detached(priority: .utility) {
            await manager.removeSpool(for: identifier)
        }
    }

    func configureDataPreview(batchSize: Int, fetcher: @escaping DataPreviewFetcher) {
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = nil
        dataPreviewState = DataPreviewState(
            batchSize: max(1, batchSize),
            fetcher: fetcher,
            nextOffset: 0,
            hasMoreData: true,
            isFetching: false
        )
    }

    func updateResultsFormattingSettings(enabled: Bool, mode: ResultsFormattingMode) {
        resultsTypeFormattingEnabled = enabled
        resultsFormattingMode = mode
    }
}
