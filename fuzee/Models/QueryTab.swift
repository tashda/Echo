import Foundation
import SwiftUI
import Combine

class QueryTab: Identifiable, ObservableObject {
    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    let connectionSessionID: UUID
    @Published var title: String
    @Published var sql: String = "SELECT current_timestamp;"
    @Published var results: QueryResultSet?
    @Published var errorMessage: String?
    @Published var isExecuting: Bool = false
    @Published var lastExecutionTime: TimeInterval?
    @Published var currentExecutionTime: TimeInterval = 0
    @Published var currentRowCount: Int?
    @Published var messages: [QueryExecutionMessage] = []
    @Published var hasExecutedAtLeastOnce: Bool = false
    @Published var splitRatio: CGFloat = 0.5
    @Published var wasCancelled: Bool = false
    @Published var structureEditor: TableStructureEditorViewModel?

    private var executionStartTime: Date?
    private var executionTimer: Timer?
    private var lastMessageTimestamp: Date?
    private var executingTask: Task<Void, Never>?

    init(connection: SavedConnection, session: DatabaseSession, connectionSessionID: UUID, title: String? = nil) {
        self.connection = connection
        self.session = session
        self.connectionSessionID = connectionSessionID
        self.title = title ?? connection.connectionName
    }

    func startExecution() {
        executionStartTime = Date()
        currentExecutionTime = 0
        currentRowCount = 0
        isExecuting = true
        wasCancelled = false
        let isFirstExecution = !hasExecutedAtLeastOnce
        hasExecutedAtLeastOnce = true
        if isFirstExecution {
            splitRatio = 0.5
        }
        lastMessageTimestamp = nil

        executingTask?.cancel()
        executingTask = nil

        // Clear previous messages
        messages.removeAll()

        let timestamp = executionStartTime ?? Date()
        appendMessage(
            message: "Query execution started",
            severity: .info,
            timestamp: timestamp,
            duration: nil
        )

        // Start timer to update current execution time
        executionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.executionStartTime else { return }
            DispatchQueue.main.async {
                self.currentExecutionTime = Date().timeIntervalSince(startTime)
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
        currentRowCount = nil
        appendMessage(
            message: "Query execution canceled",
            severity: .warning,
            timestamp: endTime,
            duration: executionStartTime.map { endTime.timeIntervalSince($0) }
        )

        executionStartTime = nil
    }

    var isStructureTab: Bool {
        structureEditor != nil
    }

    func configureStructureEditor(_ editor: TableStructureEditorViewModel) {
        structureEditor = editor
        hasExecutedAtLeastOnce = true
    }
}

extension QueryTab: Hashable {
    static func == (lhs: QueryTab, rhs: QueryTab) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
class QueryTabManager: ObservableObject {
    @Published var tabs: [QueryTab] = []
    @Published var activeTabId: UUID?

    var activeTab: QueryTab? {
        get {
            guard let id = activeTabId else { return nil }
            return tabs.first { $0.id == id }
        }
        set {
            activeTabId = newValue?.id
        }
    }

    @discardableResult
    func addTab(connection: SavedConnection, session: DatabaseSession, connectionSessionID: UUID, title: String? = nil) -> QueryTab {
        let newTab = QueryTab(connection: connection, session: session, connectionSessionID: connectionSessionID, title: title)
        tabs.append(newTab)
        activeTabId = newTab.id
        return newTab
    }

    func closeTab(id: UUID) {
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.first?.id
        }
    }

    func getTab(id: UUID) -> QueryTab? {
        return tabs.first { $0.id == id }
    }
}
