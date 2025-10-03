import Foundation
import SwiftUI
import Combine

final class WorkspaceTab: ObservableObject, Identifiable {
    enum Kind {
        case query
        case structure
    }

    enum Content {
        case query(QueryEditorState)
        case structure(TableStructureEditorViewModel)
    }

    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    let connectionSessionID: UUID

    @Published var title: String
    @Published private(set) var content: Content

    private var contentCancellable: AnyCancellable?

    init(
        connection: SavedConnection,
        session: DatabaseSession,
        connectionSessionID: UUID,
        title: String,
        content: Content
    ) {
        self.connection = connection
        self.session = session
        self.connectionSessionID = connectionSessionID
        self.title = title
        self.content = content
        subscribeToContent()
    }

    var kind: Kind {
        switch content {
        case .query: return .query
        case .structure: return .structure
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

    func setContent(_ newContent: Content) {
        content = newContent
        subscribeToContent()
        objectWillChange.send()
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
    @Published var currentRowCount: Int?
    @Published var messages: [QueryExecutionMessage] = []
    @Published var hasExecutedAtLeastOnce: Bool = false
    @Published var splitRatio: CGFloat = 0.5
    @Published var wasCancelled: Bool = false
    @Published private(set) var visibleRowLimit: Int?
    @Published private(set) var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    private let initialVisibleRowBatch = 600

    private var executionStartTime: Date?
    private var executionTimer: Timer?
    private var lastMessageTimestamp: Date?
    private var executingTask: Task<Void, Never>?
    @Published private(set) var streamingColumns: [ColumnInfo] = []
    @Published private(set) var streamingRows: [[String?]] = []

    init(sql: String = "SELECT current_timestamp;") {
        self.sql = sql
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

        let timestamp = executionStartTime ?? Date()
        appendMessage(
            message: "Query execution started",
            severity: .info,
            timestamp: timestamp,
            duration: nil
        )

        executionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.executionStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let rounded = floor(elapsed)
            DispatchQueue.main.async {
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
    }

    func consumeFinalResult(_ result: QueryResultSet) {
        streamingColumns = result.columns
        streamingRows = result.rows
        results = result
        updateRowCount(result.rows.count)
        visibleRowLimit = nil
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

    func updateClipboardContext(serverName: String?, databaseName: String?) {
        clipboardMetadata = ClipboardHistoryStore.Entry.Metadata(
            serverName: serverName,
            databaseName: databaseName,
            objectName: clipboardMetadata.objectName
        )
    }

    func updateClipboardObjectName(_ objectName: String?) {
        clipboardMetadata = ClipboardHistoryStore.Entry.Metadata(
            serverName: clipboardMetadata.serverName,
            databaseName: clipboardMetadata.databaseName,
            objectName: objectName
        )
    }
}
