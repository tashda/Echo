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

    private let initialVisibleRowBatch: Int

    private var executionStartTime: Date?
    private var executionTimer: Timer?
    private var lastMessageTimestamp: Date?
    private var executingTask: Task<Void, Never>?
    @Published private(set) var streamingColumns: [ColumnInfo] = []
    @Published private(set) var streamingRows: [[String?]] = []
    @Published private(set) var resultChangeToken: UInt64 = 0

    init(sql: String = "SELECT current_timestamp;", initialVisibleRowBatch: Int = 600) {
        self.sql = sql
        self.initialVisibleRowBatch = max(100, initialVisibleRowBatch)
    }

    func startExecution() {
        executionStartTime = Date()
        currentExecutionTime = 0
        currentRowCount = 0
        isExecuting = true
        wasCancelled = false
        visibleRowLimit = initialVisibleRowBatch

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

    func updateRowCount(_ count: Int) {
        currentRowCount = count
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
        visibleRowLimit = nil
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
        streamingColumns.removeAll(keepingCapacity: false)
        streamingRows.removeAll(keepingCapacity: false)
        results = nil
        visibleRowLimit = nil
        markResultDataChanged()
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
        markResultDataChanged()
    }

    @MainActor
    func applyStreamUpdate(_ update: QueryStreamUpdate) {
        guard !update.columns.isEmpty else { return }

        if streamingColumns.isEmpty {
            streamingColumns = update.columns
        }

        if !update.appendedRows.isEmpty {
            streamingRows.append(contentsOf: update.appendedRows)
        }

        if isExecuting {
            let currentLimit = visibleRowLimit ?? initialVisibleRowBatch
            let appendedCount = max(update.appendedRows.count, initialVisibleRowBatch / 2)
            let proposedLimit = currentLimit + appendedCount
            let cappedLimit = min(streamingRows.count, max(initialVisibleRowBatch, proposedLimit))
            visibleRowLimit = cappedLimit
        }

        let runningCount = max(update.totalRowCount, streamingRows.count)
        updateRowCount(runningCount)
        markResultDataChanged()
    }

    func consumeFinalResult(_ result: QueryResultSet) {
        streamingColumns = result.columns
        streamingRows = result.rows
        results = result
        updateRowCount(result.rows.count)
        visibleRowLimit = nil
        markResultDataChanged()
    }

    var displayedColumns: [ColumnInfo] {
        if !streamingColumns.isEmpty { return streamingColumns }
        return results?.columns ?? []
    }

    var displayedRowCount: Int {
        let available = totalAvailableRowCount
        if isExecuting, let limit = visibleRowLimit {
            return min(limit, available)
        }
        return available
    }

    var totalAvailableRowCount: Int {
        if !streamingRows.isEmpty { return streamingRows.count }
        return results?.rows.count ?? 0
    }

    func displayedRow(at index: Int) -> [String?]? {
        guard index >= 0 else { return nil }
        let count = displayedRowCount
        guard index < count else { return nil }

        if !streamingRows.isEmpty {
            return streamingRows[index]
        }
        guard let resultRows = results?.rows, index < resultRows.count else { return nil }
        return resultRows[index]
    }

    func valueForDisplay(row: Int, column: Int) -> String? {
        guard let rowValues = displayedRow(at: row), column >= 0, column < rowValues.count else {
            return nil
        }
        return rowValues[column]
    }

    func revealMoreRowsIfNeeded(forDisplayedRow row: Int) {
        guard isExecuting else { return }
        guard let limit = visibleRowLimit else { return }

        let available = streamingRows.count
        guard available > limit else { return }

        let threshold = max(limit - max(initialVisibleRowBatch / 4, 50), 0)
        guard row >= threshold else { return }

        let newLimit = min(limit + initialVisibleRowBatch, available)
        if newLimit > limit {
            visibleRowLimit = newLimit
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
