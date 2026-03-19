import Foundation
import SQLServerKit

// MARK: - Sortable computed properties for optional/nested/derived fields
// SwiftUI TableColumn requires `value:` with a Comparable keypath to enable sorting.
// Optional properties aren't Comparable, so we provide non-optional wrappers.

extension SQLServerProcessInfo {
    var sortableLoginName: String { loginName ?? "" }
    var sortableStatus: String { sessionStatus ?? "" }
    var sortableCpuTime: Int { sessionCpuTimeMs ?? 0 }
    var sortableMemory: Int { memoryUsageKB ?? 0 }
    var sortableReads: Int { sessionReads ?? 0 }
    var sortableWaitType: String { request?.waitType ?? "" }
    var sortableCommand: String { request?.sqlText ?? request?.command ?? "" }
    var sortableBlockedBy: Int { request?.blockingSessionId ?? 0 }
}

extension SQLServerFileIOStatDelta {
    var sortableDatabaseName: String { databaseName ?? "DB \(databaseId)" }
    var sortableFileName: String { fileName ?? "File \(fileId)" }
}

extension SQLServerExpensiveQuery {
    var sortableQuery: String { sqlText ?? "" }
    var sortableLastRun: Date { lastExecutionTime ?? .distantPast }
    var avgWorkerTime: Int64 { executionCount > 0 ? totalWorkerTime / Int64(executionCount) : 0 }
}

extension SQLServerWaitStatDelta {
    var avgWaitMs: Int { waitingTasksCountDelta > 0 ? waitTimeMsDelta / waitingTasksCountDelta : 0 }
    var signalPercent: Double { waitTimeMsDelta > 0 ? Double(signalWaitTimeMsDelta) / Double(waitTimeMsDelta) * 100 : 0 }
}

extension SQLServerXEEventData {
    var sortableTimestamp: Date { timestamp ?? .distantPast }
}
