import Foundation
import SwiftUI
import Combine

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
    let id = UUID()
    let fromNodeID: String
    let fromColumn: String
    let toNodeID: String
    let toColumn: String
    let relationshipName: String?
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

@MainActor
final class SchemaDiagramViewModel: ObservableObject {
    @Published var nodes: [SchemaDiagramNodeModel]
    @Published var edges: [SchemaDiagramEdge]
    let title: String
    let baseNodeID: String

    init(
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge],
        baseNodeID: String,
        title: String
    ) {
        self.nodes = nodes
        self.edges = edges
        self.baseNodeID = baseNodeID
        self.title = title
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
}

final class QueryResultsGridState {
    var cachedColumnIDs: [String] = []
    var cachedRowOrder: [Int] = []
    var cachedSort: SortCriteria?
    var lastRowCount: Int = 0
    var lastResultToken: UInt64 = 0
}

@MainActor final class QueryEditorState: ObservableObject {
    @Published var sql: String
    @Published private(set) var results: QueryResultSet?
    @Published var errorMessage: String?
    @Published var isExecuting: Bool = false
    @Published var lastExecutionTime: TimeInterval?
    @Published var currentExecutionTime: TimeInterval = 0
    @Published var currentRowCount: Int?
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

    private let initialVisibleRowBatch: Int
    private let spoolManager: ResultSpoolManager
    private var spoolHandle: ResultSpoolHandle?
    private var spoolStatsTask: Task<Void, Never>?
    @Published private(set) var resultSpoolID: UUID?
    private var didReceiveStreamingUpdate = false
    private let rowCache = ResultSpoolRowCache(pageSize: 512, maxPages: 32)
    private var streamedRowCount: Int = 0
    private let frontBufferLimit: Int

    private var executionStartTime: Date?
    private var executionTimer: Timer?
    private var lastMessageTimestamp: Date?
    private var executingTask: Task<Void, Never>?
    @Published private(set) var streamingColumns: [ColumnInfo] = []
    @Published private(set) var streamingRows: [[String?]] = []
    @Published private(set) var resultChangeToken: UInt64 = 0

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

    init(sql: String = "SELECT current_timestamp;", initialVisibleRowBatch: Int = 500, spoolManager: ResultSpoolManager) {
        self.sql = sql
        self.initialVisibleRowBatch = max(100, initialVisibleRowBatch)
        self.spoolManager = spoolManager
        self.performanceTracker = QueryPerformanceTracker(initialBatchTarget: self.initialVisibleRowBatch)
        self.frontBufferLimit = max(self.initialVisibleRowBatch, 512)
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

    func startExecution() {
        performanceTracker = QueryPerformanceTracker(initialBatchTarget: initialVisibleRowBatch)
        lastPerformanceReport = nil
        livePerformanceReport = nil
        prepareSpoolForNewExecution()
        didReceiveStreamingUpdate = false
        executionStartTime = Date()
        currentExecutionTime = 0
        currentRowCount = 0
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

    func updateRowCount(_ count: Int) {
        if currentRowCount == count {
            return
        }
        currentRowCount = count
        if var existing = results, existing.totalRowCount != count {
            existing.totalRowCount = count
            results = existing
        }
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

        let endTime = Date()
        if let startTime = executionStartTime {
            lastExecutionTime = endTime.timeIntervalSince(startTime)
        }

        wasCancelled = true
        errorMessage = nil
        if !streamingRows.isEmpty {
            let snapshot = QueryResultSet(columns: streamingColumns, rows: streamingRows)
            results = snapshot
            currentRowCount = streamingRows.count
            visibleRowLimit = streamingRows.count
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
        }
        if isResultsOnly, var preview = dataPreviewState {
            preview.isFetching = false
            dataPreviewState = preview
        }
        dataPreviewFetchTask?.cancel()
        dataPreviewFetchTask = nil
        markResultDataChanged()

        finalizeSpoolOnCompletion(cancelled: true)
        finalizePerformanceMetrics(cancelled: false)
    }

    @MainActor
    func applyStreamUpdate(_ update: QueryStreamUpdate) {
        guard !update.columns.isEmpty else { return }

        let columnsWereEmpty = streamingColumns.isEmpty
        if streamingColumns.isEmpty {
            streamingColumns = update.columns
        }

        if !update.appendedRows.isEmpty {
            let startIndex = streamedRowCount
            rowCache.ingest(rows: update.appendedRows, startingAt: startIndex)
            streamedRowCount += update.appendedRows.count

            if streamingRows.count < frontBufferLimit {
                let remainingCapacity = frontBufferLimit - streamingRows.count
                if remainingCapacity > 0 {
                    streamingRows.append(contentsOf: update.appendedRows.prefix(remainingCapacity))
                }
            }
        }

        if !update.appendedRows.isEmpty || !update.encodedRows.isEmpty {
            didReceiveStreamingUpdate = true
            submitToSpool(update: update)
        }

        let estimatedTotal = max(update.totalRowCount, streamedRowCount)

        let appendedCount = update.metrics?.batchRowCount
            ?? (update.encodedRows.isEmpty ? update.appendedRows.count : update.encodedRows.count)
        performanceTracker.recordStreamUpdate(appendedRowCount: appendedCount, totalRowCount: estimatedTotal)
        if estimatedTotal >= initialVisibleRowBatch {
            performanceTracker.recordInitialBatchReady(totalRowCount: estimatedTotal)
        }
        if let metrics = update.metrics {
            performanceTracker.recordBackendMetrics(metrics)
        }

        if isExecuting {
            let baselineLimit = max(visibleRowLimit ?? 0, initialVisibleRowBatch)
            let cappedLimit = min(estimatedTotal, baselineLimit)
            if visibleRowLimit != cappedLimit {
                visibleRowLimit = cappedLimit
            }
        }

        let previousRowCount = currentRowCount ?? 0
        let runningCount = max(estimatedTotal, currentRowCount ?? 0)
        updateRowCount(runningCount)
        let columnsUpdated = columnsWereEmpty && !streamingColumns.isEmpty
        if columnsUpdated || !update.appendedRows.isEmpty || runningCount != previousRowCount {
            markResultDataChanged()
        }

        refreshLivePerformanceReport()
    }

    func consumeFinalResult(_ result: QueryResultSet) {
        let totalRowCount = result.totalRowCount ?? result.rows.count
        performanceTracker.markResultSetReceived(totalRowCount: totalRowCount)
        streamingColumns = result.columns

        let truncatedRows = Array(result.rows.prefix(frontBufferLimit))
        rowCache.ingest(rows: truncatedRows, startingAt: 0)
        streamedRowCount = max(streamedRowCount, totalRowCount)
        streamingRows = truncatedRows

        let condensedResult = QueryResultSet(
            columns: result.columns,
            rows: truncatedRows,
            totalRowCount: totalRowCount,
            commandTag: result.commandTag
        )
        results = condensedResult

        updateRowCount(totalRowCount)

        if isResultsOnly {
            visibleRowLimit = min(initialVisibleRowBatch, totalRowCount)
        } else {
            visibleRowLimit = nil
        }
        markResultDataChanged()
        refreshLivePerformanceReport()
        finalizeSpool(with: result)
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
        let current = currentRowCount ?? 0
        let reported = results?.totalRowCount ?? 0
        return max(current, reported, streamedRowCount, streamingRows.count)
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
        return rowCache.row(at: index)
    }

    func valueForDisplay(row: Int, column: Int) -> String? {
        guard column >= 0 else { return nil }
        guard let rowValues = displayedRow(at: row), column < rowValues.count else {
            ensureRowsMaterialized(range: row..<(row + 1))
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

    private func prepareSpoolForNewExecution() {
        spoolStatsTask?.cancel()
        spoolStatsTask = nil
        rowCache.reset()
        streamedRowCount = 0
        if let previousID = resultSpoolID {
            let manager = spoolManager
            Task.detached(priority: .utility) {
                await manager.removeSpool(for: previousID)
            }
        }
        spoolHandle = nil
        resultSpoolID = nil
    }

    private func submitToSpool(update: QueryStreamUpdate) {
        guard !update.appendedRows.isEmpty || !update.encodedRows.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let handle = try await self.resolveSpoolHandle()
                let chunkSize = 128
                let rows = update.appendedRows
                let encodedRows = update.encodedRows
                var rowIndex = rows.startIndex
                var encodedIndex = encodedRows.startIndex

                func nextRowsChunk(limit: Int) -> [[String?]] {
                    guard rowIndex < rows.endIndex else { return [] }
                    let upper = rows.index(rowIndex, offsetBy: limit, limitedBy: rows.endIndex) ?? rows.endIndex
                    let slice = Array(rows[rowIndex..<upper])
                    rowIndex = upper
                    return slice
                }

                while encodedIndex < encodedRows.endIndex {
                    let upper = encodedRows.index(encodedIndex, offsetBy: chunkSize, limitedBy: encodedRows.endIndex) ?? encodedRows.endIndex
                    let encodedChunk = Array(encodedRows[encodedIndex..<upper])
                    let stringChunk = nextRowsChunk(limit: chunkSize)
                    let metrics = upper == encodedRows.endIndex && rowIndex == rows.endIndex ? update.metrics : nil
                    try await handle.append(columns: update.columns, rows: stringChunk, encodedRows: encodedChunk, metrics: metrics)
                    encodedIndex = upper
                }

                while rowIndex < rows.endIndex {
                    let stringChunk = nextRowsChunk(limit: chunkSize)
                    let metrics = rowIndex == rows.endIndex ? update.metrics : nil
                    try await handle.append(columns: update.columns, rows: stringChunk, encodedRows: [], metrics: metrics)
                }
            } catch {
#if DEBUG
                print("ResultSpool append failed: \(error)")
#endif
            }
        }
    }

    private func finalizeSpool(with result: QueryResultSet) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let streamed = await MainActor.run { self.didReceiveStreamingUpdate }
                if streamed {
                    guard let handle = await self.currentSpoolHandle() else { return }
                    try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                } else if !result.columns.isEmpty && !result.rows.isEmpty {
                    let handle = try await self.resolveSpoolHandle()
                    try await handle.append(columns: result.columns, rows: result.rows, encodedRows: [], metrics: nil)
                    try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                } else if let handle = await self.currentSpoolHandle() {
                    try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                }
            } catch {
#if DEBUG
                print("ResultSpool finalize failed: \(error)")
#endif
            }
        }
    }

    private func finalizeSpoolOnCompletion(cancelled: Bool) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            guard let handle = await self.currentSpoolHandle() else { return }
            do {
                try await handle.markFinished(commandTag: nil, metrics: nil)
            } catch {
#if DEBUG
                print("ResultSpool completion finalize failed: \(error)")
#endif
            }
        }
    }

    private func resolveSpoolHandle() async throws -> ResultSpoolHandle {
        if let existing = spoolHandle {
            return existing
        }
        let handle = try await spoolManager.makeSpoolHandle()
        spoolHandle = handle
        resultSpoolID = handle.id
        attachSpoolStats(from: handle)
        return handle
    }

    private func currentSpoolHandle() async -> ResultSpoolHandle? {
        await MainActor.run { self.spoolHandle }
    }

    private func attachSpoolStats(from handle: ResultSpoolHandle) {
        spoolStatsTask?.cancel()
        spoolStatsTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let stream = await handle.statsStream()
            for await stats in stream {
                await MainActor.run {
                    var shouldRefresh = false
                    if let metrics = stats.metrics {
                        self.performanceTracker.recordBackendMetrics(metrics)
                        shouldRefresh = true
                    }
                    if stats.rowCount > (self.currentRowCount ?? 0) {
                        self.updateRowCount(stats.rowCount)
                    }
                    if stats.isFinished {
                        shouldRefresh = true
                    }
                    if shouldRefresh {
                        self.refreshLivePerformanceReport()
                    }
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

    func ensureRowsMaterialized(forSourceIndices indices: [Int]) {
        guard !indices.isEmpty else { return }
        let sorted = Array(Set(indices)).sorted()
        guard let first = sorted.first else { return }

        var rangeStart = first
        var previous = first

        func flushRange() {
            ensureRowsMaterialized(range: rangeStart..<(previous + 1))
        }

        for index in sorted.dropFirst() {
            if index == previous + 1 {
                previous = index
                continue
            }
            flushRange()
            rangeStart = index
            previous = index
        }
        flushRange()
    }

    private func ensureRowsMaterialized(range: Range<Int>) {
        guard !range.isEmpty else { return }
        guard let handle = spoolHandle else { return }
        rowCache.prefetch(range: range, using: handle) { [weak self] in
            guard let self else { return }
            self.markResultDataChanged()
        }
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

    private func markResultDataChanged() {
        resultChangeToken &+= 1
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

            if streamingRows.count < frontBufferLimit {
                let remainingCapacity = frontBufferLimit - streamingRows.count
                if remainingCapacity > 0 {
                    streamingRows.append(contentsOf: newRows.prefix(remainingCapacity))
                }
            }

            let newTotal = streamedRowCount
            updateRowCount(newTotal)
            let currentLimit = visibleRowLimit ?? initialVisibleRowBatch
            let expandedLimit = min(newTotal, currentLimit + newRows.count)
            visibleRowLimit = expandedLimit

            if var existingResult = results {
                existingResult.columns = streamingColumns
                existingResult.rows = streamingRows
                existingResult.totalRowCount = newTotal
                results = existingResult
            } else {
                results = QueryResultSet(
                    columns: streamingColumns,
                    rows: streamingRows,
                    totalRowCount: newTotal
                )
            }

            markResultDataChanged()
        }

        preview.nextOffset = requestedOffset + newRows.count
        preview.hasMoreData = newRows.count >= preview.batchSize
        preview.isFetching = false
        dataPreviewState = preview

        if newRows.isEmpty {
            updateRowCount(streamedRowCount)
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
            finalRowCount: totalAvailableRowCount,
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
            currentRowCount: totalAvailableRowCount,
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
