import Foundation
import SwiftUI
import Combine
import os.signpost
import os.log

@MainActor final class QueryEditorState: ObservableObject {
    @Published var sql: String
    @Published var results: QueryResultSet?
    @Published var errorMessage: String?
    @Published var isExecuting: Bool = false
    @Published var lastExecutionTime: TimeInterval?
    @Published var currentExecutionTime: TimeInterval = 0
    @Published var rowProgress: RowProgress = RowProgress()
    @Published var messages: [QueryExecutionMessage] = []
    @Published var hasExecutedAtLeastOnce: Bool = false
    @Published var splitRatio: CGFloat = 0.5
    @Published var wasCancelled: Bool = false
    @Published var visibleRowLimit: Int?
    @Published var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    @Published var isResultsOnly: Bool = false
    @Published var shouldAutoExecuteOnAppear: Bool = false
    @Published var lastPerformanceReport: QueryPerformanceTracker.Report?
    @Published var livePerformanceReport: QueryPerformanceTracker.Report?
    @Published var streamingModeOverride: ResultStreamingExecutionMode = .auto
    var rowCountRefreshHandler: (() -> Void)?

    @Published var streamingMode: StreamingMode = .idle

    let initialVisibleRowBatch: Int
    let previewRowLimit: Int
    let spoolActivationThreshold: Int
    let spoolManager: ResultSpoolCoordinator
    var spoolHandle: ResultSpoolHandle?
    var ingestionService: ResultStreamIngestionService?
    var spoolStatsTask: Task<Void, Never>?
    @Published var resultSpoolID: UUID?
    var didReceiveStreamingUpdate = false
    let rowCache = ResultSpoolRowCache(pageSize: 512, maxPages: 256)
    let gridViewportForwardPrefetchRows: Int
    let gridViewportBackfillRows: Int
    var lastVisibleDisplayRange: Range<Int> = 0..<0
    var lastPrefetchedSourceRange: Range<Int> = 0..<0
    var pendingVisibleRowReloadIndexes: IndexSet?

    var lastSpoolStatsRowCount: Int = 0
    var hasAppliedFinalSpoolStats: Bool = false

    var lastBroadcastSnapshot: BroadcastSnapshot?
    let payloadFormatter = PostgresPayloadFormatter()

    var gridViewportPadding: Int {
        gridViewportForwardPrefetchRows + gridViewportBackfillRows
    }

    var gridViewportLayoutPadding: Int {
        let forwardContribution = gridViewportForwardPrefetchRows / 2
        let total = forwardContribution + gridViewportBackfillRows
        return min(max(total, 128), 256)
    }

    var streamedRowCount: Int = 0
    let frontBufferLimit: Int
    var deferredSpoolUpdates: [BufferedSpoolUpdate] = []
    var isSpoolActivationDeferred: Bool = true
    var isResultChangeCoalesced: Bool = false

    var executionStartTime: Date?
    var executionTimer: Timer?
    var lastMessageTimestamp: Date?
    var executingTask: Task<Void, Never>?
    @Published var streamingColumns: [ColumnInfo] = []
    @Published var streamingRows: [[String?]] = []
    @Published var resultChangeToken: UInt64 = 0
    @Published private(set) var resultsFormattingMode: ResultsFormattingMode = .immediate
    @Published private(set) var resultsTypeFormattingEnabled: Bool = true

    typealias DataPreviewFetcher = @Sendable (_ offset: Int, _ limit: Int) async throws -> QueryResultSet

    var dataPreviewState: DataPreviewState?
    var dataPreviewFetchTask: Task<Void, Never>?
    var performanceTracker: QueryPerformanceTracker
    lazy var formattingCoordinator: ResultRowFormattingCoordinator = {
        ResultRowFormattingCoordinator(
            formatter: PostgresPayloadFormatter()
        ) { [weak self] batch in
            self?.handleFormattedBatch(batch)
        }
    }()
    var formattingGeneration: Int = 0
    var formattingResetTask: Task<Void, Never>?
    var materializedHighWaterMark: Int = 0
    let rowDiagnosticsEnabled = ProcessInfo.processInfo.environment["ECHO_ROW_DEBUG"] == "1"
    var hasAnnouncedRowDiagnostics = false
    
    typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]
    var foreignKeyContext: ForeignKeyResolutionContext?
    var cachedForeignKeyMapping: ForeignKeyMapping = [:]
    var hasLoadedForeignKeyMapping = false
    var isLoadingForeignKeyMapping = false
    var shouldPersistResults = false
    var progressiveMaterializationTask: Task<Void, Never>?

    init(
        sql: String = "SELECT current_timestamp;",
        initialVisibleRowBatch: Int = 500,
        previewRowLimit: Int = 512,
        spoolManager: ResultSpoolCoordinator,
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
