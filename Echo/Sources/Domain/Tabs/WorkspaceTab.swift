import Foundation
import SwiftUI
import Combine
import os.signpost
import os.log

private let gridPipelineLog = OSLog(subsystem: "dk.tippr.echo", category: .pointsOfInterest)

final class WorkspaceTab: ObservableObject, Identifiable {
    struct BookmarkTabContext: Equatable {
        let bookmarkID: UUID
        let displayName: String
        let originalQuery: String

        init(bookmarkID: UUID, displayName: String, originalQuery: String) {
            self.bookmarkID = bookmarkID
            self.displayName = displayName
            self.originalQuery = originalQuery
        }

        init(bookmark: Bookmark) {
            self.bookmarkID = bookmark.id
            self.displayName = bookmark.primaryLine
            self.originalQuery = bookmark.query
        }
    }

    enum Kind {
        case query
        case structure
        case diagram
    }

    enum Content {
        case query(QueryEditorState)
        case structure(TableStructureEditorViewModel)
        case diagram(SchemaDiagramViewModel)
    }

    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    let connectionSessionID: UUID

    @Published var title: String
    @Published private(set) var content: Content
    @Published var isPinned: Bool
    let bookmarkContext: BookmarkTabContext?

    private var contentCancellable: AnyCancellable?
    let resultsGridState = QueryResultsGridState()

    init(
        connection: SavedConnection,
        session: DatabaseSession,
        connectionSessionID: UUID,
        title: String,
        content: Content,
        isPinned: Bool = false,
        bookmarkContext: BookmarkTabContext? = nil
    ) {
        self.connection = connection
        self.session = session
        self.connectionSessionID = connectionSessionID
        self.title = title
        self.content = content
        self.isPinned = isPinned
        self.bookmarkContext = bookmarkContext
        subscribeToContent()
    }

    var kind: Kind {
        switch content {
        case .query: return .query
        case .structure: return .structure
        case .diagram: return .diagram
        }
    }

    var query: QueryEditorState? {
        if case .query(let state) = content { return state }
        return nil
    }

    var structureEditor: TableStructureEditorViewModel? {
        if case .structure(let editor) = content { return editor }
        return nil
    }

    var diagram: SchemaDiagramViewModel? {
        if case .diagram(let diagram) = content { return diagram }
        return nil
    }

    func setContent(_ newContent: Content) {
        content = newContent
        subscribeToContent()
        objectWillChange.send()
    }

    func estimatedMemoryUsageBytes() -> Int {
        let baseOverhead = 96 * 1024
        switch content {
        case .query(let state):
            return baseOverhead + state.estimatedMemoryUsageBytes()
        case .structure(let editor):
            return baseOverhead + editor.estimatedMemoryUsageBytes()
        case .diagram(let diagram):
            return baseOverhead + diagram.estimatedMemoryUsageBytes()
        }
    }

    private func subscribeToContent() {
        contentCancellable = nil
        switch content {
        case .query(let state):
            state.rowCountRefreshHandler = { [weak self] in
                self?.resultsGridState.scheduleRowCountRefresh()
            }
            contentCancellable = state.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .structure(let editor):
            contentCancellable = editor.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        case .diagram(let diagram):
            contentCancellable = diagram.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
}

struct SchemaDiagramEdge: Identifiable, Hashable {
    let fromNodeID: String
    let fromColumn: String
    let toNodeID: String
    let toColumn: String
    let relationshipName: String?

    var id: String {
        [
            fromNodeID,
            fromColumn,
            toNodeID,
            toColumn,
            relationshipName ?? ""
        ].joined(separator: "|")
    }
}

struct SchemaDiagramColumn: Identifiable, Hashable {
    let id: String
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
    let isForeignKey: Bool

    init(name: String, dataType: String, isPrimaryKey: Bool, isForeignKey: Bool) {
        self.id = name
        self.name = name
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isForeignKey = isForeignKey
    }
}

enum DiagramLoadSource: Equatable {
    case live(Date)
    case cache(Date)
}

final class SchemaDiagramNodeModel: ObservableObject, Identifiable {
    let id: String
    let schema: String
    let name: String
    let displayName: String
    let columns: [SchemaDiagramColumn]
    @Published var position: CGPoint

    init(
        schema: String,
        name: String,
        columns: [SchemaDiagramColumn],
        position: CGPoint = .zero
    ) {
        self.schema = schema
        self.name = name
        self.displayName = "\(schema).\(name)"
        self.columns = columns
        self.position = position
        self.id = "\(schema).\(name)"
    }
}

struct SchemaDiagramContext: Hashable {
    let projectID: UUID?
    let connectionID: UUID
    let connectionSessionID: UUID
    let object: SchemaObjectInfo
    let cacheKey: DiagramCacheKey?
}

@MainActor
final class SchemaDiagramViewModel: ObservableObject {
    @Published var nodes: [SchemaDiagramNodeModel]
    @Published var edges: [SchemaDiagramEdge]
    @Published var isLoading: Bool
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var loadSource: DiagramLoadSource = .live(Date())
    let title: String
    let baseNodeID: String
    var layoutIdentifier: String
    var context: SchemaDiagramContext?
    var cachedStructure: DiagramStructureSnapshot?
    var cachedChecksum: String?

    init(
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge],
        baseNodeID: String,
        title: String,
        isLoading: Bool = false,
        statusMessage: String? = nil,
        errorMessage: String? = nil,
        layoutIdentifier: String? = nil,
        context: SchemaDiagramContext? = nil,
        cachedStructure: DiagramStructureSnapshot? = nil,
        cachedChecksum: String? = nil,
        loadSource: DiagramLoadSource = .live(Date())
    ) {
        self.nodes = nodes
        self.edges = edges
        self.baseNodeID = baseNodeID
        self.title = title
        self.isLoading = isLoading
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
        self.layoutIdentifier = layoutIdentifier ?? "primary"
        self.context = context
        self.cachedStructure = cachedStructure
        self.cachedChecksum = cachedChecksum
        self.loadSource = loadSource
    }

    func node(for id: String) -> SchemaDiagramNodeModel? {
        nodes.first(where: { $0.id == id })
    }

    func estimatedMemoryUsageBytes() -> Int {
        let baseOverhead = 40 * 1024
        let nodeBytes = nodes.reduce(0) { partial, node in
            let nameBytes = node.displayName.utf8.count * 2
            let columnBytes = node.columns.reduce(0) { sum, column in
                sum + column.name.utf8.count * 2 + column.dataType.utf8.count * 2 + 96
            }
            return partial + 256 + nameBytes + columnBytes
        }
        let edgeBytes = edges.reduce(0) { partial, edge in
            let fromBytes = edge.fromNodeID.utf8.count * 2
            let toBytes = edge.toNodeID.utf8.count * 2
            let nameBytes = (edge.relationshipName?.utf8.count ?? 0) * 2
            return partial + fromBytes + toBytes + nameBytes + 160
        }
        return baseOverhead + nodeBytes + edgeBytes
    }

    func layoutSnapshot() -> DiagramLayoutSnapshot {
        let positions = nodes.map { node in
            DiagramLayoutSnapshot.NodePosition(
                nodeID: node.id,
                x: Double(node.position.x),
                y: Double(node.position.y)
            )
        }
        return DiagramLayoutSnapshot(layoutID: layoutIdentifier, nodePositions: positions)
    }
}

extension Notification.Name {
    static let queryResultsRowCountDidChange = Notification.Name("dk.tippr.echo.queryResultsRowCountDidChange")
}

final class QueryResultsGridState {
    var cachedColumnIDs: [String] = []
    var cachedRowOrder: [Int] = []
    var cachedSort: SortCriteria?
    var lastRowCount: Int = 0
    var lastResultToken: UInt64 = 0
    private var isRowCountRefreshScheduled = false

    func scheduleRowCountRefresh() {
        guard !isRowCountRefreshScheduled else { return }
        isRowCountRefreshScheduled = true
#if os(macOS)
        let modes: [RunLoop.Mode] = [.default, .eventTracking]
#else
        let modes: [RunLoop.Mode] = [.default]
#endif
        RunLoop.main.perform(inModes: modes) { [weak self] in
            guard let self else { return }
            self.isRowCountRefreshScheduled = false
            NotificationCenter.default.post(name: .queryResultsRowCountDidChange, object: self)
        }
    }
}

@MainActor final class QueryEditorState: ObservableObject {
    @Published var sql: String
    @Published private(set) var results: QueryResultSet?
    @Published var errorMessage: String?
    @Published var isExecuting: Bool = false
    @Published var lastExecutionTime: TimeInterval?
    @Published var currentExecutionTime: TimeInterval = 0
    struct RowProgress: Equatable {
        /// Rows that have been received from the stream (cumulative)
        var totalReceived: Int = 0

        /// Total row count reported by the database/stream
        var totalReported: Int = 0

        /// Rows that are fully materialized and ready to display
        var materialized: Int = 0

        /// Backwards-compatible alias for `totalReported`
        var reported: Int {
            get { totalReported }
            set { totalReported = newValue }
        }

        /// Backwards-compatible alias for `totalReceived`
        var received: Int {
            get { totalReceived }
            set { totalReceived = newValue }
        }

        init(totalReceived: Int = 0, totalReported: Int = 0, materialized: Int = 0) {
            self.totalReceived = totalReceived
            self.totalReported = totalReported
            self.materialized = materialized
        }

        init(materialized: Int, reported: Int, received: Int? = nil) {
            self.init(
                totalReceived: received ?? max(materialized, reported),
                totalReported: reported,
                materialized: materialized
            )
        }

        /// Primary count to display in UI (auto-selects best available count)
        var displayCount: Int {
            totalReported > 0 ? totalReported : totalReceived
        }

        /// Whether the query has completed loading all rows
        var isComplete: Bool {
            totalReported > 0 && materialized >= totalReported
        }
    }
    @Published private(set) var rowProgress: RowProgress = RowProgress()
    @Published var messages: [QueryExecutionMessage] = []
    @Published var hasExecutedAtLeastOnce: Bool = false
    @Published var splitRatio: CGFloat = 0.5
    @Published var wasCancelled: Bool = false
    @Published private(set) var visibleRowLimit: Int?
    @Published private(set) var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    @Published var isResultsOnly: Bool = false
    @Published var shouldAutoExecuteOnAppear: Bool = false
    @Published private(set) var lastPerformanceReport: QueryPerformanceTracker.Report?
    @Published private(set) var livePerformanceReport: QueryPerformanceTracker.Report?
    var rowCountRefreshHandler: (() -> Void)?

    enum StreamingMode: Equatable {
        case idle
        case preview
        case background
        case completed
    }

    @Published private(set) var streamingMode: StreamingMode = .idle

    private let initialVisibleRowBatch: Int
    private let previewRowLimit: Int
    private let spoolActivationThreshold: Int
    private let spoolManager: ResultSpoolManager
    private var spoolHandle: ResultSpoolHandle?
    private var ingestionService: ResultStreamIngestionService?
    private var spoolStatsTask: Task<Void, Never>?
    @Published private(set) var resultSpoolID: UUID?
    private var didReceiveStreamingUpdate = false
    private let rowCache = ResultSpoolRowCache(pageSize: 512, maxPages: 32)
    private let gridViewportForwardPrefetchRows: Int
    private let gridViewportBackfillRows: Int
    private var lastVisibleDisplayRange: Range<Int> = 0..<0
    private var lastPrefetchedSourceRange: Range<Int> = 0..<0
    private var pendingVisibleRowReloadIndexes: IndexSet?

    private var lastSpoolStatsRowCount: Int = 0
    private var hasAppliedFinalSpoolStats: Bool = false

    private struct BroadcastSnapshot: Equatable {
        var rowCount: Int
        var streamingRowsCount: Int
        var visibleLimit: Int?
        var streamingMode: StreamingMode
        var columnCount: Int
    }

    private var lastBroadcastSnapshot: BroadcastSnapshot?

    var gridViewportPadding: Int {
        gridViewportForwardPrefetchRows + gridViewportBackfillRows
    }

    var gridViewportLayoutPadding: Int {
        let forwardContribution = gridViewportForwardPrefetchRows / 2
        let total = forwardContribution + gridViewportBackfillRows
        return min(max(total, 128), 256)
    }

    private struct BufferedSpoolUpdate {
        let update: QueryStreamUpdate
        let treatAsPreview: Bool
    }

    private var streamedRowCount: Int = 0
    private let frontBufferLimit: Int
    private var deferredSpoolUpdates: [BufferedSpoolUpdate] = []
    private var isSpoolActivationDeferred: Bool = true
    private var isResultChangeCoalesced: Bool = false

    private var executionStartTime: Date?
    private var executionTimer: Timer?
    private var lastMessageTimestamp: Date?
    private var executingTask: Task<Void, Never>?
    @Published private(set) var streamingColumns: [ColumnInfo] = []
    @Published private(set) var streamingRows: [[String?]] = []
    @Published private(set) var resultChangeToken: UInt64 = 0
    @Published private(set) var resultsFormattingMode: ResultsFormattingMode = .immediate
    @Published private(set) var resultsTypeFormattingEnabled: Bool = true

    typealias DataPreviewFetcher = @Sendable (_ offset: Int, _ limit: Int) async throws -> QueryResultSet

    private struct DataPreviewState {
        let batchSize: Int
        let fetcher: DataPreviewFetcher
        var nextOffset: Int
        var hasMoreData: Bool
        var isFetching: Bool
    }

    private var dataPreviewState: DataPreviewState?
    private var dataPreviewFetchTask: Task<Void, Never>?
    private var performanceTracker: QueryPerformanceTracker
    private lazy var formattingCoordinator: ResultRowFormattingCoordinator = {
        ResultRowFormattingCoordinator(
            formatCell: PostgresPayloadFormatter.stringValue(for:columnIndex:localTimeZone:)
        ) { [weak self] batch in
            self?.handleFormattedBatch(batch)
        }
    }()
    private var formattingGeneration: Int = 0
    private var formattingResetTask: Task<Void, Never>?
    private var materializedHighWaterMark: Int = 0
    private let rowDiagnosticsEnabled = ProcessInfo.processInfo.environment["ECHO_ROW_DEBUG"] == "1"
    private var hasAnnouncedRowDiagnostics = false
    struct ForeignKeyResolutionContext {
        let schema: String
        let table: String
    }
    typealias ForeignKeyMapping = [String: ColumnInfo.ForeignKeyReference]
    private var foreignKeyContext: ForeignKeyResolutionContext?
    private var cachedForeignKeyMapping: ForeignKeyMapping = [:]
    private var hasLoadedForeignKeyMapping = false
    private var isLoadingForeignKeyMapping = false
    private var shouldPersistResults = false

    init(
        sql: String = "SELECT current_timestamp;",
        initialVisibleRowBatch: Int = 500,
        previewRowLimit: Int = 512,
        spoolManager: ResultSpoolManager,
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
        let manager = spoolManager
        let identifier = resultSpoolID
        Task.detached(priority: .utility) {
            if let identifier {
                await manager.removeSpool(for: identifier)
            }
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

    func updateForeignKeyResolutionContext(schema: String?, table: String?) {
        if let schema, let table {
            foreignKeyContext = ForeignKeyResolutionContext(schema: schema, table: table)
        } else {
            foreignKeyContext = nil
        }
        cachedForeignKeyMapping = [:]
        hasLoadedForeignKeyMapping = false
        isLoadingForeignKeyMapping = false
    }

    func foreignKeyReference(for columnName: String) -> ColumnInfo.ForeignKeyReference? {
        cachedForeignKeyMapping[columnName.lowercased()]
    }

    func beginForeignKeyMappingFetch() -> (schema: String, table: String)? {
        guard let context = foreignKeyContext else { return nil }
        guard !hasLoadedForeignKeyMapping else { return nil }
        if isLoadingForeignKeyMapping {
            return nil
        }
        isLoadingForeignKeyMapping = true
        return (context.schema, context.table)
    }

    func completeForeignKeyMappingFetch(with mapping: ForeignKeyMapping) {
        cachedForeignKeyMapping = mapping
        hasLoadedForeignKeyMapping = true
        isLoadingForeignKeyMapping = false
        guard !mapping.isEmpty else { return }
        streamingColumns = applyForeignKeyMapping(to: streamingColumns, mapping: mapping)
        if var currentResults = results {
            currentResults.columns = applyForeignKeyMapping(to: currentResults.columns, mapping: mapping)
            results = currentResults
        }
        markResultDataChanged(force: true)
    }

    func failForeignKeyMappingFetch() {
        isLoadingForeignKeyMapping = false
    }

    private func applyForeignKeyMapping(to columns: [ColumnInfo], mapping: ForeignKeyMapping) -> [ColumnInfo] {
        guard !mapping.isEmpty else { return columns }
        return columns.map { column in
            var updated = column
            if updated.foreignKey == nil, let reference = mapping[column.name.lowercased()] {
                updated.foreignKey = reference
            }
            return updated
        }
    }

    func startExecution() {
        if rowDiagnosticsEnabled && !hasAnnouncedRowDiagnostics {
            hasAnnouncedRowDiagnostics = true
            print("[RowDiagnostics] Enabled for query '\(sql)'")
        }
        performanceTracker = QueryPerformanceTracker(initialBatchTarget: initialVisibleRowBatch)
        lastPerformanceReport = nil
        livePerformanceReport = nil
        materializedHighWaterMark = 0
        updateForeignKeyResolutionContext(schema: nil, table: nil)
        formattingGeneration &+= 1
        let currentToken = formattingGeneration
        formattingResetTask?.cancel()
        let coordinator = formattingCoordinator
        formattingResetTask = Task(priority: .userInitiated) { [weak self] in
            await coordinator.reset()
            await MainActor.run {
                if let self, self.formattingGeneration == currentToken {
                    self.formattingResetTask = nil
                }
            }
        }
        prepareSpoolForNewExecution()
        didReceiveStreamingUpdate = false
        executionStartTime = Date()
        currentExecutionTime = 0
        lastSpoolStatsRowCount = 0
        hasAppliedFinalSpoolStats = false
        lastBroadcastSnapshot = nil
        isExecuting = true
        wasCancelled = false
        visibleRowLimit = initialVisibleRowBatch

        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = true
            preview.nextOffset = 0
            preview.hasMoreData = true
            dataPreviewState = preview
            dataPreviewFetchTask?.cancel()
            dataPreviewFetchTask = nil
        }

        let isFirstExecution = !hasExecutedAtLeastOnce
        hasExecutedAtLeastOnce = true
        if isFirstExecution {
            splitRatio = 0.5
        }
        lastMessageTimestamp = nil

        executingTask?.cancel()
        executingTask = nil

        messages.removeAll()
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        rowProgress = RowProgress()
        streamingMode = .preview
        results = nil
        markResultDataChanged()

        let timestamp = executionStartTime ?? Date()
        appendMessage(
            message: "Query execution started",
            severity: .info,
            timestamp: timestamp,
            duration: nil
        )

        executionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startTime = self.executionStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let rounded = floor(elapsed)
                if Int(rounded) != Int(self.currentExecutionTime) {
                    self.currentExecutionTime = rounded
                }
            }
        }
    }

    func recordQueryDispatched() {
        performanceTracker.markQueryDispatched()
    }

    func finishExecution() {
        if let startTime = executionStartTime {
            lastExecutionTime = Date().timeIntervalSince(startTime)
        }
        isExecuting = false
        wasCancelled = false
        executingTask = nil
        executionTimer?.invalidate()
        executionTimer = nil
        streamingMode = .completed
        streamingMode = .completed
        let endTime = Date()
        if let startTime = executionStartTime {
            appendMessage(
                message: "Query execution finished",
                severity: .success,
                timestamp: endTime,
                duration: endTime.timeIntervalSince(startTime)
            )
        }
        executionStartTime = nil
        if isResultsOnly {
            visibleRowLimit = initialVisibleRowBatch
        } else {
            visibleRowLimit = nil
        }

        if isResultsOnly, var preview = dataPreviewState {
            let total = totalAvailableRowCount
            preview.nextOffset = total
            preview.hasMoreData = total >= preview.batchSize
            preview.isFetching = false
            dataPreviewState = preview
        }
        let finalMaterialized = max(rowProgress.materialized, totalAvailableRowCount)
        let finalReported = max(rowProgress.reported, finalMaterialized)
        rowProgress = RowProgress(
            materialized: finalMaterialized,
            reported: finalReported,
            received: max(streamedRowCount, finalMaterialized)
        )
        materializedHighWaterMark = max(materializedHighWaterMark, finalMaterialized)

        finalizeSpoolOnCompletion(cancelled: false)
        finalizePerformanceMetrics(cancelled: false)
    }

    func failExecution(with error: String) {
        isExecuting = false
        wasCancelled = false
        executingTask = nil
        executionTimer?.invalidate()
        executionTimer = nil
        let endTime = Date()
        if let startTime = executionStartTime {
            lastExecutionTime = endTime.timeIntervalSince(startTime)
        }
        appendMessage(
            message: "Query execution failed",
            severity: .error,
            timestamp: endTime,
            duration: executionStartTime.map { endTime.timeIntervalSince($0) },
            metadata: ["error": error]
        )
        executionStartTime = nil
        shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: false)
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        results = nil
        if isResultsOnly {
            visibleRowLimit = initialVisibleRowBatch
        } else {
            visibleRowLimit = nil
        }
        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = nil
        rowProgress = RowProgress()
        materializedHighWaterMark = 0
        markResultDataChanged()

        finalizePerformanceMetrics(cancelled: true)
    }

    func appendMessage(
        message: String,
        severity: QueryExecutionMessage.Severity,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        procedure: String? = nil,
        line: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        let index = messages.count + 1
        let delta: TimeInterval
        if let lastTimestamp = lastMessageTimestamp {
            delta = timestamp.timeIntervalSince(lastTimestamp)
        } else {
            delta = 0
        }

        let entry = QueryExecutionMessage(
            index: index,
            message: message,
            timestamp: timestamp,
            severity: severity,
            delta: delta,
            duration: duration,
            procedure: procedure,
            line: line,
            metadata: metadata
        )
        messages.append(entry)
        lastMessageTimestamp = timestamp
    }

    func setExecutingTask(_ task: Task<Void, Never>) {
        executingTask?.cancel()
        executingTask = task
    }

    func cancelExecution() {
        if let task = executingTask {
            task.cancel()
        } else if isExecuting {
            markCancellationCompleted()
        }
    }

    func markCancellationCompleted() {
        executingTask = nil
        isExecuting = false
        executionTimer?.invalidate()
        executionTimer = nil
        streamingMode = .completed

        let endTime = Date()
        if let startTime = executionStartTime {
            lastExecutionTime = endTime.timeIntervalSince(startTime)
        }

        wasCancelled = true
        errorMessage = nil
        if !streamingRows.isEmpty {
            let snapshot = QueryResultSet(columns: streamingColumns, rows: streamingRows)
            results = snapshot
            let retainedCount = streamingRows.count
            let updatedReported = max(rowProgress.reported, retainedCount)
            rowProgress = RowProgress(
                materialized: retainedCount,
                reported: updatedReported,
                received: max(streamedRowCount, retainedCount)
            )
            visibleRowLimit = retainedCount
            materializedHighWaterMark = retainedCount
        }
        appendMessage(
            message: "Query execution canceled",
            severity: .warning,
            timestamp: endTime,
            duration: executionStartTime.map { endTime.timeIntervalSince($0) }
        )

        executionStartTime = nil
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        if results == nil {
            visibleRowLimit = nil
            materializedHighWaterMark = 0
            rowProgress = RowProgress()
        }
        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = nil
        markResultDataChanged()

        shouldPersistResults = false
        finalizeSpoolOnCompletion(cancelled: true)
        finalizePerformanceMetrics(cancelled: false)
    }

    @MainActor
    func applyStreamUpdate(_ update: QueryStreamUpdate) {
        guard !update.columns.isEmpty else { return }

        if streamingMode == .idle {
            streamingMode = .preview
        }

        let modeForSpool = streamingMode
        let columnsWereEmpty = streamingColumns.isEmpty
        if columnsWereEmpty {
            streamingColumns = update.columns
        }

        let rawRows = update.rawRows
        let appendedRange = update.rowRange

        let appendedRowCount: Int = {
            if let range = appendedRange {
                return range.count
            }
            if !rawRows.isEmpty {
                return rawRows.count
            }
            if !update.appendedRows.isEmpty {
                return update.appendedRows.count
            }
            if !update.encodedRows.isEmpty {
                return update.encodedRows.count
            }
            return 0
        }()

#if DEBUG
        print("[WorkspaceTab] applyStreamUpdate appendedRowCount=\(appendedRowCount) appendedRows=\(update.appendedRows.count) rawRows=\(rawRows.count) encodedRows=\(update.encodedRows.count) totalRowCount=\(update.totalRowCount)")
#endif
        if rowDiagnosticsEnabled {
            if let range = appendedRange, range.upperBound > update.totalRowCount {
                debugReportRowAnomaly(stage: "applyStreamUpdate", message: "rowRange upperBound \(range.upperBound) exceeds reported total \(update.totalRowCount)")
            }
            if appendedRowCount > 0, streamingRows.count + appendedRowCount > update.totalRowCount {
                debugReportRowAnomaly(stage: "applyStreamUpdate", message: "incoming batch would exceed total (\(streamingRows.count + appendedRowCount) > \(update.totalRowCount))")
            }
        }

        os_log("ApplyStreamUpdate begin rows=%{public}d", log: gridPipelineLog, type: .info, appendedRowCount)
        print("[Signpost] ApplyStreamUpdate begin rows=\(appendedRowCount)")
        if #available(macOS 10.14, *) {
            os_signpost(.begin, log: gridPipelineLog, name: "ApplyStreamUpdate", "%{public}d rows", appendedRowCount)
        }
        defer {
            os_log("ApplyStreamUpdate end", log: gridPipelineLog, type: .info)
            print("[Signpost] ApplyStreamUpdate end")
            if #available(macOS 10.14, *) {
                os_signpost(.end, log: gridPipelineLog, name: "ApplyStreamUpdate")
            }
        }

        if appendedRowCount > 0 {
            let previousStreamed = streamedRowCount
            let provisionalStreamed = previousStreamed &+ appendedRowCount
            let knownTotals = [
                update.totalRowCount,
                rowProgress.totalReported,
                rowProgress.totalReceived,
                materializedHighWaterMark,
                results?.totalRowCount ?? 0
            ].filter { $0 > 0 }
            let upperBound = knownTotals.max() ?? provisionalStreamed
            if rowDiagnosticsEnabled, provisionalStreamed > upperBound {
                debugReportRowAnomaly(
                    stage: "applyStreamUpdate",
                    message: "clamping streamedRowCount provisional=\(provisionalStreamed) upperBound=\(upperBound) totals=\(knownTotals)"
                )
            }
            streamedRowCount = min(provisionalStreamed, upperBound)
            debugTrackRowCountChange(
                event: "applyStreamUpdate",
                previous: previousStreamed,
                current: streamedRowCount,
                details: "appended=\(appendedRowCount) total=\(update.totalRowCount) rowRange=\(appendedRange.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil") raw=\(rawRows.count) encoded=\(update.encodedRows.count)"
            )
            didReceiveStreamingUpdate = true

            let updatedProgress = RowProgress(
                totalReceived: max(streamedRowCount, rowProgress.totalReceived),
                totalReported: rowProgress.totalReported,
                materialized: rowProgress.materialized
            )
            if updatedProgress != rowProgress {
                rowProgress = updatedProgress
            }
        }

        let estimatedTotal = max(update.totalRowCount, streamedRowCount)
        if appendedRowCount > 0 {
            performanceTracker.recordStreamUpdate(appendedRowCount: appendedRowCount, totalRowCount: estimatedTotal)
        }
        if estimatedTotal >= initialVisibleRowBatch {
            performanceTracker.recordInitialBatchReady(totalRowCount: estimatedTotal)
        }
        if let metrics = update.metrics {
            performanceTracker.recordBackendMetrics(metrics)
        }

        let nextStreamedCount = streamedRowCount + appendedRowCount
        if streamingMode == .preview,
           nextStreamedCount >= spoolActivationThreshold {
            streamingMode = .background
            if !isResultsOnly, visibleRowLimit != nil {
                visibleRowLimit = nil
            }
            shouldPersistResults = true
        }

        let effectiveShouldPersist = shouldPersistResults || streamingMode == .background
        let bufferLimit = effectiveShouldPersist ? frontBufferLimit : max(frontBufferLimit, estimatedTotal)
        let remainingBufferCapacity = max(bufferLimit - streamingRows.count, 0)
        if effectiveShouldPersist,
           appendedRowCount > 0,
           remainingBufferCapacity <= 0 {
            let spoolEncodedRows: [ResultBinaryRow]
            let spoolRawRows: [ResultRowPayload]
            let spoolFormattedRows: [[String?]]
            if !update.encodedRows.isEmpty {
                spoolEncodedRows = update.encodedRows
                spoolRawRows = []
                spoolFormattedRows = []
            } else if !update.rawRows.isEmpty {
                spoolEncodedRows = []
                spoolRawRows = update.rawRows
                spoolFormattedRows = []
            } else {
                spoolEncodedRows = []
                spoolRawRows = []
                spoolFormattedRows = update.appendedRows
            }
            let spoolPayload = QueryStreamUpdate(
                columns: update.columns,
                appendedRows: spoolFormattedRows,
                encodedRows: spoolEncodedRows,
                rawRows: spoolRawRows,
                totalRowCount: update.totalRowCount,
                metrics: update.metrics,
                rowRange: update.rowRange
            )
            submitToSpool(update: spoolPayload, mode: modeForSpool)
            let resolvedTotal = estimatedTotal > 0 ? estimatedTotal : rowProgress.totalReported
            if resolvedTotal > 0, streamedRowCount > resolvedTotal {
                streamedRowCount = resolvedTotal
            }
            let receivedSource = max(streamedRowCount, rowProgress.totalReceived)
            let newReported = resolvedTotal
            let newReceived = resolvedTotal > 0 ? min(receivedSource, resolvedTotal) : receivedSource
            let newMaterialized = resolvedTotal > 0 ? min(rowProgress.materialized, resolvedTotal) : rowProgress.materialized
            if rowProgress.totalReported != newReported
                || rowProgress.totalReceived != newReceived
                || rowProgress.materialized != newMaterialized {
                rowProgress = RowProgress(
                    totalReceived: newReceived,
                    totalReported: newReported,
                    materialized: newMaterialized
                )
            }
            markResultDataChanged()
            if streamingMode == .preview || isExecuting {
                refreshLivePerformanceReport()
            }
            activateSpoolIfNeeded()
            return
        }

        let columnsForBatch = streamingColumns.isEmpty ? update.columns : streamingColumns
        let treatAsPreview = !effectiveShouldPersist && (modeForSpool == .preview || modeForSpool == .idle)
        let shouldDefer = resultsTypeFormattingEnabled && resultsFormattingMode == .deferred && !rawRows.isEmpty
        var spoolPreviewRows: [[String?]] = []

        if !shouldDefer {
            let rangeLower = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
            let previewCap = max(frontBufferLimit, previewRowLimit)
            let displayCap = effectiveShouldPersist ? bufferLimit : previewCap
            let maxDisplayIndex = min(rangeLower + appendedRowCount, displayCap)
            let displayCount = max(0, min(appendedRowCount, maxDisplayIndex - rangeLower))
            let formattedRows: [[String?]]
            if !update.appendedRows.isEmpty {
                if effectiveShouldPersist && displayCount == 0 {
                    formattedRows = []
                } else if !effectiveShouldPersist || displayCount >= update.appendedRows.count {
                    formattedRows = update.appendedRows
                } else {
                    formattedRows = Array(update.appendedRows.prefix(displayCount))
                }
            } else if !rawRows.isEmpty {
                if effectiveShouldPersist {
                    let payloadsToFormat = Array(rawRows.prefix(displayCount))
                    formattedRows = formatRowsSynchronously(payloadsToFormat)
                } else {
                    formattedRows = formatRowsSynchronously(rawRows)
                }
            } else {
                formattedRows = []
            }

            if !formattedRows.isEmpty {
#if DEBUG
                if rowDiagnosticsEnabled {
                    if let firstBad = formattedRows.firstIndex(where: { row in
                        !row.isEmpty && row.allSatisfy { $0 == nil }
                    }) {
                        debugReportRowAnomaly(stage: "applyStreamUpdate", message: "formattedRows batch contains all-nil row at offset \(firstBad) totalColumns=\(formattedRows[firstBad].count)")
                    }
                }
#endif
                let startIndex = rangeLower
                let resolvedRange = startIndex..<(startIndex + formattedRows.count)
                integrateFormattedRows(
                    rows: formattedRows,
                    range: resolvedRange,
                    totalRowCount: estimatedTotal,
                    metrics: update.metrics,
                    treatAsPreview: treatAsPreview,
                    columns: columnsForBatch
                )
                if treatAsPreview {
                    spoolPreviewRows = formattedRows
                }
            }
        } else {
            let rangeLower = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
            let previewCap = max(frontBufferLimit, previewRowLimit)
            let displayCap = effectiveShouldPersist ? bufferLimit : previewCap
            let maxDisplayIndex = min(rangeLower + appendedRowCount, displayCap)
            var immediateCount = 0
            var integratedRowsForSpool: [[String?]] = []
            if let range = appendedRange, !update.appendedRows.isEmpty {
                let displayCount = max(0, min(update.appendedRows.count, maxDisplayIndex - rangeLower))
                immediateCount = displayCount
                if displayCount > 0 {
                    let rowsToIntegrate = displayCount < update.appendedRows.count
                        ? Array(update.appendedRows.prefix(displayCount))
                        : update.appendedRows
                    integratedRowsForSpool = rowsToIntegrate
                    let immediateRange = range.lowerBound..<(range.lowerBound + rowsToIntegrate.count)
                    integrateFormattedRows(
                        rows: rowsToIntegrate,
                        range: immediateRange,
                        totalRowCount: estimatedTotal,
                        metrics: update.metrics,
                        treatAsPreview: treatAsPreview,
                        columns: columnsForBatch
                    )
                }
            } else if !rawRows.isEmpty {
                let previewRemaining = max(previewRowLimit - rowProgress.materialized, 0)
                let displayBudget = max(0, maxDisplayIndex - rangeLower)
                immediateCount = min(previewRemaining, min(rawRows.count, displayBudget))
                if immediateCount > 0 {
                    let startIndex = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
                    let immediatePayloads = Array(rawRows.prefix(immediateCount))
                    let immediateRows = formatRowsSynchronously(immediatePayloads)
                    let immediateRange = startIndex..<(startIndex + immediateCount)
                    integratedRowsForSpool = immediateRows
                    integrateFormattedRows(
                        rows: immediateRows,
                        range: immediateRange,
                        totalRowCount: estimatedTotal,
                        metrics: update.metrics,
                        treatAsPreview: true,
                        columns: columnsForBatch
                    )
                }
            }

            if rawRows.count > immediateCount {
                let startIndex = appendedRange?.lowerBound ?? max(streamingRows.count, rowProgress.materialized)
                let deferredStart = startIndex + immediateCount
                let deferredRows = Array(rawRows.dropFirst(immediateCount))
                let deferredRange = deferredStart..<(deferredStart + deferredRows.count)
                enqueueDeferredBatch(
                    rows: deferredRows,
                    range: deferredRange,
                    totalRowCount: estimatedTotal,
                    metrics: update.metrics,
                    treatAsPreview: false,
                    columns: columnsForBatch
                )
            }
            if treatAsPreview {
                spoolPreviewRows = integratedRowsForSpool
            }
        }

        let spoolEncodedRows: [ResultBinaryRow]
        let spoolRawRows: [ResultRowPayload]
        let fallbackAppendedRows: [[String?]]
        if !update.encodedRows.isEmpty {
            spoolEncodedRows = update.encodedRows
            spoolRawRows = []
            fallbackAppendedRows = []
        } else if !update.rawRows.isEmpty {
            spoolEncodedRows = []
            spoolRawRows = update.rawRows
            fallbackAppendedRows = []
        } else {
            spoolEncodedRows = []
            spoolRawRows = []
            fallbackAppendedRows = update.appendedRows
        }
        let appendedRowsForSpool: [[String?]]
        if treatAsPreview {
            appendedRowsForSpool = !spoolPreviewRows.isEmpty ? spoolPreviewRows : []
        } else {
            appendedRowsForSpool = fallbackAppendedRows
        }

        let spoolPayload = QueryStreamUpdate(
            columns: update.columns,
            appendedRows: appendedRowsForSpool,
            encodedRows: spoolEncodedRows,
            rawRows: spoolRawRows,
            totalRowCount: update.totalRowCount,
            metrics: update.metrics,
            rowRange: update.rowRange
        )
        submitToSpool(update: spoolPayload, mode: modeForSpool)

        if appendedRowCount > 0 && spoolPreviewRows.isEmpty {
            let resolvedTotal = estimatedTotal > 0 ? estimatedTotal : rowProgress.totalReported
            if resolvedTotal > 0, streamedRowCount > resolvedTotal {
                streamedRowCount = resolvedTotal
            }
            let receivedSource = max(streamedRowCount, rowProgress.totalReceived)
            let newReported = resolvedTotal
            let newReceived = resolvedTotal > 0 ? min(receivedSource, resolvedTotal) : receivedSource
            let newMaterialized = resolvedTotal > 0 ? min(rowProgress.materialized, resolvedTotal) : rowProgress.materialized
            if rowProgress.totalReported != newReported
                || rowProgress.totalReceived != newReceived
                || rowProgress.materialized != newMaterialized {
                rowProgress = RowProgress(
                    totalReceived: newReceived,
                    totalReported: newReported,
                    materialized: newMaterialized
                )
            }
            markResultDataChanged()
        }

        if streamingMode == .preview,
           streamedRowCount >= spoolActivationThreshold {
            streamingMode = .background
            if !isResultsOnly, visibleRowLimit != nil {
                visibleRowLimit = nil
            }
            shouldPersistResults = true
        }

        if columnsWereEmpty {
            markResultDataChanged()
        }

        if streamingMode == .preview || isExecuting {
            refreshLivePerformanceReport()
        }

        activateSpoolIfNeeded()
    }

    func consumeFinalResult(_ result: QueryResultSet) {
        let totalRowCount = result.totalRowCount ?? result.rows.count
        performanceTracker.markResultSetReceived(totalRowCount: totalRowCount)
        streamingMode = .completed
        streamingColumns = result.columns
        shouldPersistResults = shouldPersistResults || totalRowCount >= spoolActivationThreshold

        let bufferLimit = shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, totalRowCount)
        let truncatedRows = Array(result.rows.prefix(bufferLimit))
        rowCache.ingest(rows: truncatedRows, startingAt: 0)
        let previousStreamed = streamedRowCount
        let resolvedStreamed = max(streamedRowCount, totalRowCount)
        debugTrackRowCountChange(
            event: "consumeFinalResult",
            previous: previousStreamed,
            current: resolvedStreamed,
            details: "resultTotal=\(totalRowCount) truncated=\(truncatedRows.count)"
        )
        streamedRowCount = resolvedStreamed

        if streamingRows.isEmpty || streamingRows.count < truncatedRows.count {
            streamingRows = truncatedRows
        } else {
            for index in 0..<truncatedRows.count {
                streamingRows[index] = truncatedRows[index]
            }
        }

        let condensedResult = QueryResultSet(
            columns: result.columns,
            rows: truncatedRows,
            totalRowCount: totalRowCount,
            commandTag: result.commandTag
        )
        results = condensedResult

        let updatedMaterialized = max(rowProgress.materialized, truncatedRows.count)
        let updatedReported = max(rowProgress.reported, totalRowCount)
        rowProgress = RowProgress(
            materialized: updatedMaterialized,
            reported: updatedReported,
            received: streamedRowCount
        )
        materializedHighWaterMark = max(materializedHighWaterMark, updatedMaterialized)

        if isResultsOnly {
            visibleRowLimit = min(initialVisibleRowBatch, totalRowCount)
        } else {
            visibleRowLimit = nil
        }
        refreshMaterializedProgress()
        markResultDataChanged()
        refreshLivePerformanceReport()
        if shouldPersistResults {
            activateSpoolIfNeeded()
            finalizeSpool(with: result)
        } else {
            shouldPersistResults = false
            deferredSpoolUpdates.removeAll(keepingCapacity: false)
            ingestionService = nil
            spoolHandle = nil
            resultSpoolID = nil
            spoolStatsTask?.cancel()
            spoolStatsTask = nil
        }
    }

    var displayedColumns: [ColumnInfo] {
        if !streamingColumns.isEmpty { return streamingColumns }
        return results?.columns ?? []
    }

    var displayedRowCount: Int {
        let available = totalAvailableRowCount
        if let limit = visibleRowLimit {
            return min(limit, available)
        }
        return available
    }

    var totalAvailableRowCount: Int {
        let materialized = max(materializedHighWaterMark, streamingRows.count, rowProgress.materialized)
        if rowProgress.totalReported > 0 {
            return min(rowProgress.totalReported, materialized)
        }
        let received = max(streamedRowCount, rowProgress.totalReceived)
        return max(materialized, received)
    }

    func displayedRow(at index: Int) -> [String?]? {
        guard index >= 0 else { return nil }
        let count = displayedRowCount
        guard index < count else { return nil }

        if index < streamingRows.count {
            return streamingRows[index]
        }

        if let cached = rowCache.row(at: index) {
            return cached
        }

        if let resultRows = results?.rows, index < resultRows.count {
            return resultRows[index]
        }

        ensureRowsMaterialized(range: index..<(index + 1))
        let resolved = rowCache.row(at: index)
        if resolved == nil, rowDiagnosticsEnabled {
            debugReportRowAnomaly(
                stage: "displayedRow",
                message: "row \(index) unavailable after fetch (streamingRows=\(streamingRows.count) cacheContiguous=\(rowCache.contiguousMaterializedCount()) totalAvailable=\(totalAvailableRowCount))"
            )
        }
        return resolved
    }

    func valueForDisplay(row: Int, column: Int) -> String? {
        guard column >= 0 else { return nil }
        guard let rowValues = displayedRow(at: row) else {
            ensureRowsMaterialized(range: row..<(row + 1))
#if DEBUG
            if rowDiagnosticsEnabled {
                debugReportRowAnomaly(stage: "valueForDisplay", message: "row \(row) unavailable for column \(column)")
            }
#endif
            return nil
        }
        if column >= rowValues.count {
            ensureRowsMaterialized(range: row..<(row + 1))
#if DEBUG
            if rowDiagnosticsEnabled {
                debugReportRowAnomaly(stage: "valueForDisplay", message: "row \(row) column \(column) beyond count \(rowValues.count)")
            }
#endif
            return nil
        }
        return rowValues[column]
    }

    func recordTableViewUpdate(visibleRowCount: Int, totalAvailableRowCount: Int) {
        performanceTracker.recordTableReload()
        guard totalAvailableRowCount > 0 else { return }
        let threshold = min(initialVisibleRowBatch, totalAvailableRowCount)
        if visibleRowCount >= threshold {
            performanceTracker.recordVisibleInitialLimitSatisfied()
        }
    }

    func revealMoreRowsIfNeeded(forDisplayedRow row: Int) {
        guard isExecuting || isResultsOnly else { return }
        guard let limit = visibleRowLimit else { return }

        let threshold = max(limit - max(initialVisibleRowBatch / 4, 50), 0)
        guard row >= threshold else { return }

        let available = totalAvailableRowCount
        if available > limit {
            let newLimit = min(limit + initialVisibleRowBatch, available)
            if newLimit > limit {
                visibleRowLimit = newLimit
                if isResultsOnly {
                    markResultDataChanged()
                }
            }
            return
        }

        if isResultsOnly {
            requestAdditionalDataPreviewRows()
        }
    }

    // MARK: - Result Spooling

    @MainActor
    private func prepareSpoolForNewExecution() {
        spoolStatsTask?.cancel()
        spoolStatsTask = nil
        streamingMode = .idle
        shouldPersistResults = false

        if let existingService = ingestionService {
            Task.detached(priority: .utility) {
                await existingService.cancel()
            }
        }
        ingestionService = nil
        deferredSpoolUpdates.removeAll(keepingCapacity: false)
        isSpoolActivationDeferred = true

        rowCache.reset()
        streamedRowCount = 0
        rowProgress = RowProgress()
        materializedHighWaterMark = 0
        lastVisibleDisplayRange = 0..<0
        lastPrefetchedSourceRange = 0..<0
        if let previousID = resultSpoolID {
            let manager = spoolManager
            Task.detached(priority: .utility) {
                await manager.removeSpool(for: previousID)
            }
        }
        spoolHandle = nil
        resultSpoolID = nil
    }

    @MainActor
    private func submitToSpool(update: QueryStreamUpdate, mode: StreamingMode) {
        let treatAsPreview = (mode == .preview || mode == .idle)
        if !shouldPersistResults {
            deferredSpoolUpdates.append(.init(update: update, treatAsPreview: treatAsPreview))
            return
        }
        if shouldDeferSpool(for: mode) {
            deferredSpoolUpdates.append(.init(update: update, treatAsPreview: treatAsPreview))
            return
        }

        let service = ensureIngestionService()
        Task.detached(priority: .utility) {
            await service.enqueue(update: update, isPreview: treatAsPreview)
        }
    }

    @MainActor
    private func shouldDeferSpool(for mode: StreamingMode) -> Bool {
        guard isSpoolActivationDeferred else { return false }
        return mode == .preview || mode == .idle
    }

    @MainActor
    @discardableResult
    private func ensureIngestionService() -> ResultStreamIngestionService {
        if let service = ingestionService {
            return service
        }
        let manager = spoolManager
        let service = ResultStreamIngestionService(
            spoolManager: manager,
            rowCache: rowCache,
            onSpoolReady: { [weak self] handle in
                guard let self else { return }
                self.spoolHandle = handle
                self.resultSpoolID = handle.id
                self.attachSpoolStats(from: handle)
            }
        )
        ingestionService = service
        return service
    }

    @MainActor
    private func activateSpoolIfNeeded(force: Bool = false) {
        guard shouldPersistResults else { return }
        guard isSpoolActivationDeferred else { return }
        if !force {
            guard streamingMode == .background || streamingMode == .completed else { return }
        }

        isSpoolActivationDeferred = false

        guard !deferredSpoolUpdates.isEmpty else { return }
        let buffered = deferredSpoolUpdates
        deferredSpoolUpdates.removeAll(keepingCapacity: false)
        let service = ensureIngestionService()
        let pendingUpdates: [(QueryStreamUpdate, Bool)] = buffered.map { update in
            (update.update, update.treatAsPreview)
        }

        Task.detached(priority: .utility) {
            for (update, treatAsPreview) in pendingUpdates {
                await service.enqueue(update: update, isPreview: treatAsPreview)
            }
        }
    }

    @MainActor
    private func finalizeSpool(with result: QueryResultSet) {
        guard shouldPersistResults else { return }
        let service = ingestionService
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            if let service {
                await service.finalize(with: result)
            } else if !result.columns.isEmpty || !result.rows.isEmpty {
                do {
                    let handle = try await self.spoolManager.makeSpoolHandle()
                    if !result.rows.isEmpty {
                        try await handle.append(
                            columns: result.columns,
                            rows: result.rows,
                            encodedRows: [],
                            rowRange: 0..<result.rows.count,
                            metrics: nil
                        )
                    }
                    try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                    await MainActor.run {
                        self.spoolHandle = handle
                        self.resultSpoolID = handle.id
                        self.attachSpoolStats(from: handle)
                    }
                } catch {
#if DEBUG
                    print("ResultSpool finalize failed: \(error)")
#endif
                }
            }
            await MainActor.run {
                self.ingestionService = nil
            }
        }
    }

    @MainActor
    private func finalizeSpoolOnCompletion(cancelled _: Bool) {
        let currentService = ingestionService

        guard shouldPersistResults else {
            Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                if let service = currentService {
                    await service.cancel()
                }
                await MainActor.run {
                    self.ingestionService = nil
                    self.spoolHandle = nil
                    self.resultSpoolID = nil
                    self.deferredSpoolUpdates.removeAll(keepingCapacity: false)
                    self.shouldPersistResults = false
                }
            }
            return
        }
        if isSpoolActivationDeferred {
            deferredSpoolUpdates.removeAll(keepingCapacity: false)
        }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            if let service = currentService {
                await service.finalize(commandTag: nil, metrics: nil)
            } else {
                let handle = await MainActor.run { self.spoolHandle }
#if DEBUG
                if handle == nil {
                    print("ResultSpoolOnCompletion skipped: no active spool")
                }
#endif
                guard let handle else { return }
                do {
                    try await handle.markFinished(commandTag: nil, metrics: nil)
                } catch {
#if DEBUG
                    print("ResultSpool completion finalize failed: \(error)")
#endif
                }
            }
            await MainActor.run {
                self.ingestionService = nil
            }
        }
    }

    private func attachSpoolStats(from handle: ResultSpoolHandle) {
        spoolStatsTask?.cancel()
        spoolStatsTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let stream = await handle.statsStream()
            for await stats in stream {
                await MainActor.run {
                    self.applySpoolStats(stats)
                }
                if stats.isFinished { break }
            }
            await MainActor.run {
                if self.spoolStatsTask?.isCancelled == false {
                    self.spoolStatsTask = nil
                }
            }
        }
    }

    private func applySpoolStats(_ stats: ResultSpoolStats) {
        var shouldRefreshReport = false
        if let metrics = stats.metrics {
            performanceTracker.recordBackendMetrics(metrics)
            shouldRefreshReport = true
        }

        let previousCount = lastSpoolStatsRowCount
        if stats.rowCount > previousCount {
            lastSpoolStatsRowCount = stats.rowCount
            if rowDiagnosticsEnabled && stats.rowCount > streamedRowCount {
                debugReportRowAnomaly(
                    stage: "spoolStats",
                    message: "spool rowCount \(stats.rowCount) exceeds streamedRowCount \(streamedRowCount)"
                )
            }
            let newReported = max(rowProgress.totalReported, stats.rowCount)
            let newReceived = max(max(streamedRowCount, stats.rowCount), rowProgress.totalReceived)
            if rowProgress.totalReported != newReported || rowProgress.totalReceived != newReceived {
                rowProgress = RowProgress(
                    totalReceived: newReceived,
                    totalReported: newReported,
                    materialized: rowProgress.materialized
                )
                markResultDataChanged()
                if var existing = results, existing.totalRowCount != newReported {
                    existing.totalRowCount = newReported
                    results = existing
                }
            }
            if streamingMode == .background, !isResultsOnly, visibleRowLimit != nil {
                visibleRowLimit = nil
            }
            shouldRefreshReport = true
            if !lastPrefetchedSourceRange.isEmpty {
                ensureRowsMaterialized(range: lastPrefetchedSourceRange)
            }
        }

        if stats.isFinished && !hasAppliedFinalSpoolStats {
            hasAppliedFinalSpoolStats = true
            if !isExecuting {
                markResultDataChanged()
            }
            shouldRefreshReport = true
        }

        if shouldRefreshReport {
            refreshLivePerformanceReport()
        }
    }

    func updateVisibleGridWindow(displayedRange: Range<Int>, sourceIndices: [Int]) {
        lastVisibleDisplayRange = displayedRange
        guard !sourceIndices.isEmpty else { return }

        let sorted = Array(Set(sourceIndices)).sorted()
        guard let minSource = sorted.first, let maxSource = sorted.last else {
            return
        }

        let available = totalAvailableRowCount
        let lower = max(minSource - gridViewportBackfillRows, 0)
        let desiredUpper = maxSource + 1 + gridViewportForwardPrefetchRows
        let upper = max(lower, min(desiredUpper, max(available, desiredUpper)))
        let targetRange = lower..<upper
        guard !targetRange.isEmpty else { return }

        lastPrefetchedSourceRange = targetRange

        ensureRowsMaterialized(range: targetRange)
    }

    private func ensureRowsMaterialized(range: Range<Int>) {
        guard !range.isEmpty else { return }
        let token = formattingGeneration
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.formattingCoordinator.prioritize(range: range, token: token)
        }
        guard let handle = spoolHandle else { return }
        rowCache.prefetch(range: range, using: handle) { [weak self] fetchedRange in
            self?.handleMaterializedRange(fetchedRange)
        }
    }

    private func handleMaterializedRange(_ fetchedRange: Range<Int>) {
        guard !fetchedRange.isEmpty else { return }

        refreshMaterializedProgress()

        let visibleRange = lastVisibleDisplayRange
        if visibleRange.isEmpty {
            enqueueVisibleRowReload(for: fetchedRange)
            return
        }

        let lower = max(fetchedRange.lowerBound, visibleRange.lowerBound)
        let upper = min(fetchedRange.upperBound, visibleRange.upperBound)
        guard lower < upper else { return }

        enqueueVisibleRowReload(for: lower..<upper)
    }

    private func enqueueVisibleRowReload(for range: Range<Int>) {
        guard !range.isEmpty else { return }
        if pendingVisibleRowReloadIndexes == nil {
            pendingVisibleRowReloadIndexes = IndexSet()
        }
        pendingVisibleRowReloadIndexes?.insert(integersIn: range)
        markResultDataChanged(force: true)
    }

    private func enqueueDeferredBatch(
        rows: [ResultRowPayload],
        range: Range<Int>,
        totalRowCount: Int,
        metrics: QueryStreamMetrics?,
        treatAsPreview: Bool,
        columns: [ColumnInfo]
    ) {
        guard !rows.isEmpty else { return }
        #if DEBUG
        print("[WorkspaceTab] integrateFormattedRows rows=\(rows.count) range=\(range) totalRowCount=\(totalRowCount ?? -1)")
        #endif
        let token = formattingGeneration
        let resetTask = formattingResetTask
        Task.detached(priority: .utility) { [weak self] in
            if let resetTask {
                _ = await resetTask.value
            }
            guard let self else { return }
            await self.formattingCoordinator.enqueue(
                range: range,
                rows: rows,
                totalRowCount: totalRowCount,
                metrics: metrics,
                treatAsPreview: treatAsPreview,
                columns: columns,
                token: token
            )
        }
    }

    private func handleFormattedBatch(_ batch: ResultRowFormattingCoordinator.FormattedBatch) {
        guard batch.token == formattingGeneration else { return }
        guard !batch.rows.isEmpty else { return }
        integrateFormattedRows(
            rows: batch.rows,
            range: batch.range,
            totalRowCount: batch.totalRowCount,
            metrics: batch.metrics,
            treatAsPreview: batch.treatAsPreview,
            columns: batch.columns
        )
    }

    private func integrateFormattedRows(
        rows: [[String?]],
        range: Range<Int>,
        totalRowCount: Int,
        metrics: QueryStreamMetrics?,
        treatAsPreview: Bool,
        columns: [ColumnInfo]
    ) {
        guard !rows.isEmpty else { return }
        os_log("IntegrateFormattedRows begin rows=%{public}d", log: gridPipelineLog, type: .info, rows.count)
        print("[Signpost] IntegrateFormattedRows begin rows=\(rows.count)")
        if #available(macOS 10.14, *) {
            os_signpost(.begin, log: gridPipelineLog, name: "IntegrateFormattedRows", "%{public}d rows", rows.count)
        }
        defer {
            os_log("IntegrateFormattedRows end", log: gridPipelineLog, type: .info)
            print("[Signpost] IntegrateFormattedRows end")
            if #available(macOS 10.14, *) {
                os_signpost(.end, log: gridPipelineLog, name: "IntegrateFormattedRows")
            }
        }
        if rowDiagnosticsEnabled {
            if totalRowCount >= 0 && range.upperBound > totalRowCount {
                debugReportRowAnomaly(stage: "integrateFormattedRows", message: "range \(range) overshoots total \(totalRowCount) rows=\(rows.count)")
            }
            if totalRowCount >= 0 && streamingRows.count > totalRowCount {
                debugReportRowAnomaly(stage: "integrateFormattedRows", message: "pre-merge streamingRows \(streamingRows.count) already exceeds total \(totalRowCount)")
            }
        }
        rowCache.ingest(rows: rows, startingAt: range.lowerBound)

        if range.lowerBound < streamingRows.count {
            let overlapEnd = min(range.upperBound, streamingRows.count)
            if overlapEnd > range.lowerBound {
                let overlapCount = overlapEnd - range.lowerBound
                for index in 0..<overlapCount {
                    streamingRows[range.lowerBound + index] = rows[index]
                }
            }
        }

        let bufferLimit = shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, totalRowCount)
        if streamingRows.count < bufferLimit && range.upperBound > streamingRows.count {
            let insertionLower = max(streamingRows.count, range.lowerBound)
            let offset = insertionLower - range.lowerBound
            if offset < rows.count {
                let slice = rows[offset...]
                let remainingCapacity = bufferLimit - streamingRows.count
                if remainingCapacity > 0 {
                    streamingRows.append(contentsOf: slice.prefix(remainingCapacity))
#if DEBUG
                    if rowDiagnosticsEnabled {
                        let appendedSlice = Array(slice.prefix(remainingCapacity))
                        if let badIndex = appendedSlice.firstIndex(where: { $0.allSatisfy { $0 == nil } }) {
                            let absoluteRow = insertionLower + badIndex
                            debugReportRowAnomaly(stage: "integrateFormattedRows", message: "appended all-nil row at \(absoluteRow) columns=\(appendedSlice[badIndex].count)")
                        }
                    }
#endif
                }
            }
        }

        if totalRowCount >= 0 {
            let cappedTotal = totalRowCount
            if streamingRows.count > cappedTotal {
                streamingRows.removeSubrange(cappedTotal..<streamingRows.count)
            }
            rowCache.clamp(to: cappedTotal)
            if streamedRowCount > cappedTotal {
                streamedRowCount = cappedTotal
            }
            if materializedHighWaterMark > cappedTotal {
                materializedHighWaterMark = cappedTotal
            }
            if rowDiagnosticsEnabled && streamingRows.count > cappedTotal {
                debugReportRowAnomaly(stage: "integrateFormattedRows", message: "post-trim streamingRows \(streamingRows.count) still exceeds capped total \(cappedTotal)")
            }
        }

        let contiguous = computeContiguousMaterializedCount()
        materializedHighWaterMark = contiguous
        let newReported = max(totalRowCount, contiguous)
        let newReceived = max(streamedRowCount, contiguous)
        if rowProgress.totalReported != newReported
            || rowProgress.totalReceived != newReceived
            || rowProgress.materialized != contiguous {
            rowProgress = RowProgress(
                totalReceived: newReceived,
                totalReported: newReported,
                materialized: contiguous
            )
        }

        if isExecuting && streamingMode == .preview {
            let baselineLimit = max(visibleRowLimit ?? 0, initialVisibleRowBatch)
            let availableRows = rowProgress.materialized
            let cappedLimit = min(totalRowCount, baselineLimit, availableRows)
            if visibleRowLimit != cappedLimit {
                visibleRowLimit = cappedLimit
            }
        }

        let visibleRange = lastVisibleDisplayRange
        if visibleRange.isEmpty {
            enqueueVisibleRowReload(for: range)
        } else {
            let lower = max(range.lowerBound, visibleRange.lowerBound)
            let upper = min(range.upperBound, visibleRange.upperBound)
            if lower < upper {
                enqueueVisibleRowReload(for: lower..<upper)
            }
        }

        markResultDataChanged()
    }

    @MainActor
    private func formatRowsSynchronously(_ payloads: [ResultRowPayload]) -> [[String?]] {
        guard !payloads.isEmpty else { return [] }
        return payloads.map { row in
            row.cells.enumerated().map { index, cell in
                PostgresPayloadFormatter.stringValue(for: cell, columnIndex: index)
            }
        }
    }

    private func debugReportRowAnomaly(stage: String, message: @autoclosure () -> String) {
        guard rowDiagnosticsEnabled else { return }
        print("[RowDiagnostics][\(stage)] \(message()) streamingRows=\(streamingRows.count) materialized=\(materializedHighWaterMark) reported=\(rowProgress.totalReported) received=\(rowProgress.totalReceived) streamedCount=\(streamedRowCount)")
    }

    private func debugTrackRowCountChange(event: String, previous: Int, current: Int, details: @autoclosure () -> String) {
#if DEBUG
        guard rowDiagnosticsEnabled, previous != current else { return }
        print("[RowDiagnostics][\(event)] streamedRowCount \(previous) -> \(current) \(details())")
#endif
    }

    private func computeContiguousMaterializedCount() -> Int {
        max(streamingRows.count, rowCache.contiguousMaterializedCount())
    }

    private func refreshMaterializedProgress() {
        let contiguous = computeContiguousMaterializedCount()
        if contiguous > materializedHighWaterMark {
            materializedHighWaterMark = contiguous
            let reported = max(rowProgress.totalReported, materializedHighWaterMark)
            let received = max(streamedRowCount, rowProgress.totalReceived)
            rowProgress = RowProgress(
                totalReceived: received,
                totalReported: reported,
                materialized: materializedHighWaterMark
            )
            markResultDataChanged()
        }
    }

    func consumePendingVisibleRowReloadIndexes() -> IndexSet? {
        let pending = pendingVisibleRowReloadIndexes
        pendingVisibleRowReloadIndexes = nil
        return pending
    }

    func updateClipboardContext(serverName: String?, databaseName: String?, connectionColorHex: String?) {
        clipboardMetadata = ClipboardHistoryStore.Entry.Metadata(
            serverName: serverName,
            databaseName: databaseName,
            objectName: clipboardMetadata.objectName,
            connectionColorHex: connectionColorHex
        )
    }

    func updateClipboardObjectName(_ objectName: String?) {
        clipboardMetadata = ClipboardHistoryStore.Entry.Metadata(
            serverName: clipboardMetadata.serverName,
            databaseName: clipboardMetadata.databaseName,
            objectName: objectName,
            connectionColorHex: clipboardMetadata.connectionColorHex
        )
    }

    private func markResultDataChanged(force: Bool = false) {
        let snapshot = BroadcastSnapshot(
            rowCount: rowProgress.materialized,
            streamingRowsCount: streamingRows.count,
            visibleLimit: visibleRowLimit,
            streamingMode: streamingMode,
            columnCount: streamingColumns.count
        )
        if !force && lastBroadcastSnapshot == snapshot {
            return
        }
        lastBroadcastSnapshot = snapshot

        if !force && isResultChangeCoalesced {
            return
        }
        isResultChangeCoalesced = true
        rowCountRefreshHandler?()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resultChangeToken &+= 1
            self.isResultChangeCoalesced = false
        }
    }

    private func requestAdditionalDataPreviewRows() {
        guard var preview = dataPreviewState else { return }
        guard preview.hasMoreData, !preview.isFetching else { return }

        let offset = preview.nextOffset
        let limit = preview.batchSize

        preview.isFetching = true
        dataPreviewState = preview

        let fetcher = preview.fetcher
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = Task { [weak self] in
            do {
                let result = try await fetcher(offset, limit)
                await MainActor.run {
                    self?.handleAdditionalPreviewResult(result, requestedOffset: offset, requestedLimit: limit)
                }
            } catch {
                await MainActor.run {
                    self?.handleAdditionalPreviewFailure(error)
                }
            }
        }
    }

    private func handleAdditionalPreviewResult(
        _ result: QueryResultSet,
        requestedOffset: Int,
        requestedLimit: Int
    ) {
        dataPreviewFetchTask = nil
        guard var preview = dataPreviewState else { return }

        let newRows = result.rows
        if streamingColumns.isEmpty {
            streamingColumns = result.columns
        }

        if !newRows.isEmpty {
            let startIndex = streamedRowCount
            rowCache.ingest(rows: newRows, startingAt: startIndex)
            streamedRowCount += newRows.count
            debugTrackRowCountChange(
                event: "previewFetch",
                previous: startIndex,
                current: streamedRowCount,
                details: "fetched=\(newRows.count) requestedOffset=\(requestedOffset) requestedLimit=\(requestedLimit)"
            )

            let bufferLimit = shouldPersistResults ? frontBufferLimit : max(frontBufferLimit, streamedRowCount)
            if streamingRows.count < bufferLimit {
                let remainingCapacity = bufferLimit - streamingRows.count
                if remainingCapacity > 0 {
                    streamingRows.append(contentsOf: newRows.prefix(remainingCapacity))
                }
            }

            refreshMaterializedProgress()

            let newTotal = streamedRowCount
            let newMaterialized = max(rowProgress.materialized, streamingRows.count)
            let newReported = max(rowProgress.reported, newTotal)
            if rowProgress.materialized != newMaterialized
                || rowProgress.totalReported != newReported
                || rowProgress.totalReceived != streamedRowCount {
                rowProgress = RowProgress(
                    totalReceived: streamedRowCount,
                    totalReported: newReported,
                    materialized: newMaterialized
                )
            }
            let currentLimit = visibleRowLimit ?? initialVisibleRowBatch
            let expandedLimit = min(newTotal, currentLimit + newRows.count)
            visibleRowLimit = expandedLimit

            if var existingResult = results {
                existingResult.columns = streamingColumns
                existingResult.rows = streamingRows
                existingResult.totalRowCount = newReported
                results = existingResult
            } else {
                results = QueryResultSet(
                    columns: streamingColumns,
                    rows: streamingRows,
                    totalRowCount: newReported
                )
            }

            markResultDataChanged()
        }

        preview.nextOffset = requestedOffset + newRows.count
        preview.hasMoreData = newRows.count >= preview.batchSize
        preview.isFetching = false
        dataPreviewState = preview

        if newRows.isEmpty {
            let newReported = max(rowProgress.totalReported, streamedRowCount)
            if rowProgress.totalReported != newReported || rowProgress.totalReceived != streamedRowCount {
                rowProgress = RowProgress(
                    totalReceived: streamedRowCount,
                    totalReported: newReported,
                    materialized: rowProgress.materialized
                )
            }
        }

        if newRows.isEmpty {
            appendMessage(
                message: "No additional data available",
                severity: .info
            )
        } else if newRows.count < requestedLimit {
            appendMessage(
                message: "Loaded \(newRows.count) additional rows (end of results)",
                severity: .info
            )
        } else {
            appendMessage(
                message: "Loaded \(newRows.count) additional rows",
                severity: .info
            )
        }
    }

    private func handleAdditionalPreviewFailure(_ error: Error) {
        dataPreviewFetchTask = nil
        if var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        let nsError = error as NSError
        appendMessage(
            message: "Failed to load additional preview rows",
            severity: .error,
            metadata: ["error": nsError.localizedDescription]
        )
    }

    private func finalizePerformanceMetrics(cancelled: Bool) {
        let alreadyReported = lastPerformanceReport != nil
        let report = performanceTracker.finalize(
            cancelled: cancelled,
            finalRowCount: rowProgress.reported,
            estimatedMemoryBytes: estimatedMemoryUsageBytes()
        )
        lastPerformanceReport = report
        livePerformanceReport = report
        if !alreadyReported {
            appendPerformanceMessage(report: report)
        }
    }

    private func refreshLivePerformanceReport() {
        livePerformanceReport = performanceTracker.snapshot(
            currentRowCount: rowProgress.materialized,
            estimatedMemoryBytes: estimatedMemoryUsageBytes()
        )
    }

    private func appendPerformanceMessage(report: QueryPerformanceTracker.Report) {
        var segments: [String] = []

        if let dispatch = report.timings.startToDispatch {
            segments.append("dispatch \(formattedDuration(dispatch))")
        }

        let firstRowInterval = report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate
        if let firstRowInterval {
            var label = "first-row \(formattedDuration(firstRowInterval))"
            if let firstBatch = report.firstBatchSize, firstBatch > 0 {
                label += " (\(firstBatch))"
            }
            segments.append(label)
        }

        if let initialBatch = report.timings.startToInitialBatch {
            segments.append("data-ready \(formattedDuration(initialBatch))")
        }

        if let gridReady = report.timings.startToVisibleInitialLimit {
            segments.append("grid-ready \(formattedDuration(gridReady))")
        }

        if let total = report.timings.startToFinish {
            segments.append("finished \(formattedDuration(total))")
        }

        if let cpuTotal = report.cpuTotalSeconds {
            segments.append("cpu \(formattedDuration(cpuTotal))")
        }

        if let rss = report.residentMemoryBytes {
            segments.append("rss \(formattedBytes(rss))")
        }

        if let rssDelta = report.residentMemoryDeltaBytes, rssDelta != 0 {
            segments.append("rssΔ \(formattedSignedBytes(rssDelta))")
        }

        segments.append("rows \(report.totalRows)")
        segments.append("batches \(report.batchCount)")
        if report.largestBatchSize > 0 {
            segments.append("largest \(report.largestBatchSize)")
        }
        if let memory = report.estimatedMemoryBytes {
            segments.append("est-mem \(formattedBytes(memory))")
        }
        if report.cancelled {
            segments.append("cancelled true")
        }

        var consoleSegments = segments
        if let backend = report.backendSamples.last {
            consoleSegments.append("latest-batch rows=\(backend.batchRowCount)")
            consoleSegments.append("latest-total \(backend.cumulativeRowCount)")
            consoleSegments.append("decode \(formattedDuration(backend.decodeDuration))")
            consoleSegments.append("wait \(formattedDuration(backend.networkWaitDuration))")
        }
        print("[QueryPerformance] \(consoleSegments.joined(separator: ", "))")

        var metadata: [String: String] = [
            "rows": "\(report.totalRows)",
            "batchCount": "\(report.batchCount)",
            "largestBatchSize": "\(report.largestBatchSize)",
            "initialBatchTarget": "\(report.initialBatchTarget)",
            "cancelled": report.cancelled ? "true" : "false",
            "timelineSamples": "\(report.timeline.count)"
        ]
        if let firstBatch = report.firstBatchSize {
            metadata["firstBatchSize"] = "\(firstBatch)"
        }
        if let memory = report.estimatedMemoryBytes {
            metadata["estimatedMemoryBytes"] = "\(memory)"
            metadata["estimatedMemoryDisplay"] = formattedBytes(memory)
        }

        if let cpuUser = report.cpuUserSeconds {
            metadata["cpuUserSeconds"] = String(format: "%.6f", cpuUser)
        }
        if let cpuSystem = report.cpuSystemSeconds {
            metadata["cpuSystemSeconds"] = String(format: "%.6f", cpuSystem)
        }
        if let cpuTotal = report.cpuTotalSeconds {
            metadata["cpuTotalSeconds"] = String(format: "%.6f", cpuTotal)
        }
        if let resident = report.residentMemoryBytes {
            metadata["residentMemoryBytes"] = "\(resident)"
            metadata["residentMemoryDisplay"] = formattedBytes(resident)
        }
        if let residentDelta = report.residentMemoryDeltaBytes {
            metadata["residentMemoryDeltaBytes"] = "\(residentDelta)"
            metadata["residentMemoryDeltaDisplay"] = formattedSignedBytes(residentDelta)
        }
        if let maxResident = report.maxResidentMemoryBytes {
            metadata["maxResidentMemoryBytes"] = "\(maxResident)"
            metadata["maxResidentMemoryDisplay"] = formattedBytes(maxResident)
        }
        if let virtual = report.virtualMemoryBytes {
            metadata["virtualMemoryBytes"] = "\(virtual)"
            metadata["virtualMemoryDisplay"] = formattedBytes(virtual)
        }
        if let value = millisecondsString(report.timings.startToDispatch) {
            metadata["startToDispatchMs"] = value
        }
        if let value = millisecondsString(report.timings.dispatchToFirstUpdate) {
            metadata["dispatchToFirstUpdateMs"] = value
        }
        if let value = millisecondsString(report.timings.startToFirstUpdate) {
            metadata["startToFirstUpdateMs"] = value
        }
        if let value = millisecondsString(report.timings.startToInitialBatch) {
            metadata["startToInitialBatchMs"] = value
        }
        if let value = millisecondsString(report.timings.startToVisibleInitialLimit) {
            metadata["startToVisibleInitialLimitMs"] = value
        }
        if let value = millisecondsString(report.timings.startToResultSet) {
            metadata["startToResultSetMs"] = value
        }
        if let value = millisecondsString(report.timings.startToFinish) {
            metadata["startToFinishMs"] = value
        }
        if let value = millisecondsString(report.timings.resultSetToFinish) {
            metadata["resultSetToFinishMs"] = value
        }

        appendMessage(
            message: "Execution metrics: \(segments.joined(separator: ", "))",
            severity: .debug,
            metadata: metadata
        )
    }

    private func formattedDuration(_ value: TimeInterval?) -> String {
        guard let value else { return "n/a" }
        if value >= 1.0 {
            return String(format: "%.2f s", value)
        }
        return String(format: "%.0f ms", value * 1_000)
    }

    private func millisecondsString(_ value: TimeInterval?) -> String? {
        guard let value else { return nil }
        return String(format: "%.2f", value * 1_000)
    }

    private func formattedBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 B" }
        let units: [String] = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024.0, unitIndex < units.count - 1 {
            value /= 1024.0
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private func formattedSignedBytes(_ bytes: Int) -> String {
        if bytes == 0 { return "0 B" }
        let sign = bytes < 0 ? "-" : "+"
        return "\(sign)\(formattedBytes(abs(bytes)))"
    }

    func estimatedMemoryUsageBytes() -> Int {
        var total = 64 * 1024
        total += sql.utf8.count * 2
        total += messages.count * 160

        let columnCount = displayedColumns.count
        total += columnCount * 192

        if let results {
            total += estimatedBytes(for: results.rows)
        } else if !streamingRows.isEmpty {
            total += estimatedBytes(for: streamingRows)
        }

        if let visibleLimit = visibleRowLimit, isExecuting {
            total += visibleLimit * columnCount * 4
        }

        return total
    }

    private func estimatedBytes(for rows: [[String?]]) -> Int {
        guard !rows.isEmpty else { return 0 }
        let maxSamples = 2048
        var sampledCells = 0
        var sampledBytes = 0
        var totalCells = 0

        for row in rows {
            totalCells += row.count
            for value in row {
                if sampledCells < maxSamples {
                    let length = value?.utf8.count ?? 0
                    sampledBytes += length + 16
                    sampledCells += 1
                }
            }
        }

        if sampledCells == 0 { return totalCells * 16 }
        let average = sampledBytes / sampledCells
        return average * totalCells
    }
}
