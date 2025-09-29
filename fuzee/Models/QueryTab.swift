import Foundation
import SwiftUI
import Combine

class QueryTab: Identifiable, ObservableObject {
    let id = UUID()
    let connection: SavedConnection
    let session: DatabaseSession
    @Published var title: String
    @Published var sql: String = "SELECT current_timestamp;"
    @Published var results: QueryResultSet?
    @Published var errorMessage: String?
    @Published var isExecuting: Bool = false
    @Published var lastExecutionTime: TimeInterval?
    @Published var currentExecutionTime: TimeInterval = 0
    @Published var currentRowCount: Int?

    private var executionStartTime: Date?
    private var executionTimer: Timer?

    init(connection: SavedConnection, session: DatabaseSession, title: String? = nil) {
        self.connection = connection
        self.session = session
        self.title = title ?? connection.connectionName
    }

    func startExecution() {
        executionStartTime = Date()
        currentExecutionTime = 0
        currentRowCount = 0
        isExecuting = true

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
        executionTimer?.invalidate()
        executionTimer = nil
        executionStartTime = nil
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
    func addTab(connection: SavedConnection, session: DatabaseSession, title: String? = nil) -> QueryTab {
        let newTab = QueryTab(connection: connection, session: session, title: title)
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