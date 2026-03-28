import Foundation
import SwiftUI
import MySQLKit
import SQLServerKit
import PostgresWire

@MainActor @Observable
final class ActivityMonitorViewModel {
    struct GraphPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let value: Double
    }

    @ObservationIgnored private let monitor: any DatabaseActivityMonitoring
    @ObservationIgnored private let mysqlSession: MySQLSession?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    let connectionSessionID: UUID
    let connectionID: UUID
    let databaseType: DatabaseType

    var latestSnapshot: DatabaseActivitySnapshot?
    var isRunning: Bool = true
    var refreshInterval: TimeInterval = 5.0
    var permissionDenied: Bool = false
    var selectedSection: String? = nil

    /// True once we have a snapshot with delta data populated (requires at least 2 collection cycles).
    /// Views should gate content display on this rather than `latestSnapshot != nil`.
    var isReady: Bool {
        guard let snapshot = latestSnapshot else { return false }
        switch snapshot {
        case .mssql(let snap):
            return snap.waitsDelta != nil && snap.fileIODelta != nil
        case .postgres(let snap):
            return snap.databaseStatsDelta != nil
        case .mysql:
            return true
        }
    }

    // MSSQL Extended Events (nil for non-MSSQL connections)
    var extendedEventsVM: ExtendedEventsViewModel?
    var profilerVM: ProfilerViewModel?
    var selectedMySQLPerformanceReport: MySQLPerformanceReportKind = .statementAnalysis
    var mysqlPerformanceReport: MySQLPerformanceReport?
    var mysqlPerformanceReportError: String?
    var isLoadingMySQLPerformanceReport = false

    // MSSQL sparkline history
    var cpuHistory: [GraphPoint] = []
    var waitingTasksHistory: [GraphPoint] = []
    var ioHistory: [GraphPoint] = []
    var throughputHistory: [GraphPoint] = []

    // Postgres sparkline history
    var connectionCountHistory: [GraphPoint] = []
    var cacheHitHistory: [GraphPoint] = []
    var deadTuplesHistory: [GraphPoint] = []
    var outgoingTrafficHistory: [GraphPoint] = []

    private let maxHistoryItems = 60

    init(
        monitor: any DatabaseActivityMonitoring,
        mysqlSession: MySQLSession? = nil,
        connectionSessionID: UUID,
        connectionID: UUID,
        databaseType: DatabaseType,
        refreshInterval: TimeInterval = 5.0
    ) {
        self.monitor = monitor
        self.mysqlSession = mysqlSession
        self.connectionSessionID = connectionSessionID
        self.connectionID = connectionID
        self.databaseType = databaseType
        self.refreshInterval = refreshInterval
        startStreaming()
    }

    func startStreaming() {
        isRunning = true
        permissionDenied = false
        streamTask?.cancel()
        streamTask = Task {
            do {
                let stream = monitor.streamSnapshots(every: refreshInterval)
                for try await snapshot in stream {
                    self.latestSnapshot = snapshot
                    updateHistory(with: snapshot)
                }
                // Stream ended naturally (not cancelled) — check if it's because of permission denial
                if latestSnapshot == nil || isEmptySnapshot(latestSnapshot) {
                    permissionDenied = true
                }
            } catch {
                // Check if error is permission related
            }
            isRunning = false
        }
    }

    private func isEmptySnapshot(_ snapshot: DatabaseActivitySnapshot?) -> Bool {
        guard let snapshot else { return true }
        switch snapshot {
        case .mssql(let snap):
            return snap.overview == nil && snap.processes.isEmpty && snap.waits.isEmpty && snap.expensiveQueries.isEmpty
        case .postgres:
            return false
        case .mysql(let snap):
            return snap.processes.isEmpty
        }
    }

    func stopStreaming() {
        isRunning = false
        streamTask?.cancel()
        streamTask = nil
    }

    func refresh() {
        Task {
            if let snap = try? await monitor.snapshot() {
                self.latestSnapshot = snap
                updateHistory(with: snap)
            }
        }
    }

    func loadMySQLPerformanceReport() {
        guard let mysqlSession else { return }

        isLoadingMySQLPerformanceReport = true
        mysqlPerformanceReportError = nil

        Task {
            do {
                let report = try await selectedMySQLPerformanceReport.load(using: mysqlSession.client.performance)
                self.mysqlPerformanceReport = report
                self.isLoadingMySQLPerformanceReport = false
            } catch {
                self.mysqlPerformanceReport = nil
                self.mysqlPerformanceReportError = error.localizedDescription
                self.isLoadingMySQLPerformanceReport = false
            }
        }
    }

    func killSession(id: Int) async throws {
        try await monitor.killSession(id: id)
        refresh()
    }

    func killMySQLQuery(id: Int) async throws {
        guard let mysqlSession, let threadID = UInt32(exactly: id) else { return }
        try await mysqlSession.client.admin.killQuery(threadID: threadID)
        refresh()
    }

    private func updateHistory(with snapshot: DatabaseActivitySnapshot) {
        let now = snapshot.capturedAt

        switch snapshot {
        case .mssql(let snap):
            if let ov = snap.overview {
                appendHistory(&cpuHistory, value: ov.processorTimePercent, timestamp: now)
                appendHistory(&waitingTasksHistory, value: Double(ov.waitingTasksCount), timestamp: now)
                appendHistory(&ioHistory, value: ov.databaseIOMBPerSec, timestamp: now)
                appendHistory(&throughputHistory, value: ov.batchRequestsPerSec, timestamp: now)
            }
        case .postgres(let snap):
            if let ov = snap.overview {
                appendHistory(&connectionCountHistory, value: Double(ov.connectionsCount), timestamp: now)
                appendHistory(&cacheHitHistory, value: ov.cacheHitPercent, timestamp: now)
                appendHistory(&throughputHistory, value: ov.transactionsPerSec, timestamp: now)
                appendHistory(&deadTuplesHistory, value: Double(ov.totalDeadTuples), timestamp: now)
                appendHistory(&ioHistory, value: ov.databaseIOMBPerSec, timestamp: now)
            }
        case .mysql(let snap):
            appendHistory(&connectionCountHistory, value: Double(snap.overview?.currentConnections ?? snap.processes.count), timestamp: now)
            if let queriesPerSecond = snap.overview?.queriesPerSecond {
                appendHistory(&throughputHistory, value: queriesPerSecond, timestamp: now)
            }
            if let bytesReceivedPerSecond = snap.overview?.bytesReceivedPerSecond {
                appendHistory(&ioHistory, value: bytesReceivedPerSecond / 1024, timestamp: now)
            }
            if let bytesSentPerSecond = snap.overview?.bytesSentPerSecond {
                appendHistory(&outgoingTrafficHistory, value: bytesSentPerSecond / 1024, timestamp: now)
            }
            if let bufferPoolUsagePercent = snap.overview?.bufferPoolUsagePercent {
                appendHistory(&cacheHitHistory, value: bufferPoolUsagePercent, timestamp: now)
            }
        }
    }

    private func appendHistory(_ history: inout [GraphPoint], value: Double, timestamp: Date) {
        history.append(GraphPoint(timestamp: timestamp, value: value))
        if history.count > maxHistoryItems {
            history.removeFirst()
        }
    }

    func estimatedMemoryUsageBytes() -> Int {
        let historySize = (cpuHistory.count + waitingTasksHistory.count + ioHistory.count +
                           throughputHistory.count + connectionCountHistory.count +
                           cacheHitHistory.count + deadTuplesHistory.count +
                           outgoingTrafficHistory.count) * 32
        return 1024 * 512 + historySize
    }
}
