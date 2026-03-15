import Foundation
import SwiftUI
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
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    let connectionSessionID: UUID

    var latestSnapshot: DatabaseActivitySnapshot?
    var isRunning: Bool = true
    var refreshInterval: TimeInterval = 5.0

    var cpuHistory: [GraphPoint] = []
    var waitingTasksHistory: [GraphPoint] = []
    var ioHistory: [GraphPoint] = []
    var throughputHistory: [GraphPoint] = []
    
    // For opening query windows in the correct context
    var latestSnapshotSessionID: UUID? {
        latestSnapshot != nil ? connectionSessionID : nil
    }

    private let maxHistoryItems = 60 

    init(monitor: any DatabaseActivityMonitoring, connectionSessionID: UUID) {
        self.monitor = monitor
        self.connectionSessionID = connectionSessionID
        startStreaming()
    }
    
    func startStreaming() {
        isRunning = true
        streamTask?.cancel()
        streamTask = Task {
            do {
                let stream = monitor.streamSnapshots(every: refreshInterval)
                for try await snapshot in stream {
                    self.latestSnapshot = snapshot
                    updateHistory(with: snapshot)
                }
            } catch {
                isRunning = false
            }
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

    func killSession(id: Int) async throws {
        try await monitor.killSession(id: id)
        // Instant refresh to show the process is gone
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
                appendHistory(&cpuHistory, value: ov.processorTimePercent, timestamp: now)
                appendHistory(&waitingTasksHistory, value: Double(ov.waitingTasksCount), timestamp: now)
                appendHistory(&ioHistory, value: ov.databaseIOMBPerSec, timestamp: now)
                appendHistory(&throughputHistory, value: ov.transactionsPerSec, timestamp: now)
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
        let historySize = (cpuHistory.count + waitingTasksHistory.count + ioHistory.count + throughputHistory.count) * 32
        return 1024 * 512 + historySize 
    }
}
