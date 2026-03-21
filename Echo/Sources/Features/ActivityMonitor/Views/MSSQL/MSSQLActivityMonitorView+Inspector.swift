import SwiftUI
import SQLServerKit

extension MSSQLActivityMonitorView {

    // MARK: - Inspector

    func pushProcessInspector(ids: Set<SQLServerProcessInfo.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let proc = snap.processes.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Session ID", value: "\(proc.sessionId)"),
            .init(label: "Login", value: proc.loginName ?? "\u{2014}"),
            .init(label: "Host", value: proc.hostName ?? "\u{2014}"),
            .init(label: "Program", value: proc.programName ?? "\u{2014}"),
            .init(label: "Client Address", value: proc.clientNetAddress ?? "\u{2014}"),
            .init(label: "Session Status", value: proc.sessionStatus ?? "\u{2014}"),
            .init(label: "CPU (session)", value: "\(proc.sessionCpuTimeMs ?? 0) ms"),
            .init(label: "Memory", value: "\(proc.memoryUsageKB ?? 0) KB"),
            .init(label: "Reads (session)", value: "\(proc.sessionReads ?? 0)"),
            .init(label: "Writes (session)", value: "\(proc.sessionWrites ?? 0)")
        ]
        if let req = proc.request {
            fields.append(.init(label: "Request Status", value: req.status ?? "\u{2014}"))
            fields.append(.init(label: "Command", value: req.command ?? "\u{2014}"))
            if let cpu = req.cpuTimeMs {
                fields.append(.init(label: "CPU (request)", value: "\(cpu) ms"))
            }
            if let elapsed = req.totalElapsedMs {
                fields.append(.init(label: "Elapsed", value: "\(elapsed) ms"))
            }
            if let wait = req.waitType, !wait.isEmpty {
                fields.append(.init(label: "Wait Type", value: wait))
                if let waitMs = req.waitTimeMs {
                    fields.append(.init(label: "Wait Time", value: "\(waitMs) ms"))
                }
            }
            if let blocker = req.blockingSessionId, blocker > 0 {
                fields.append(.init(label: "Blocked By", value: "Session \(blocker)"))
            }
            if let start = req.startTime {
                fields.append(.init(label: "Started", value: start.formatted(date: .omitted, time: .standard)))
            }
            if let pct = req.percentComplete, pct > 0 {
                fields.append(.init(label: "Progress", value: String(format: "%.1f%%", pct)))
            }
        }
        let subtitle: String
        if let blocker = proc.request?.blockingSessionId, blocker > 0 {
            subtitle = "Blocked by SID \(blocker)"
        } else {
            subtitle = proc.sessionStatus ?? "unknown"
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Session \(proc.sessionId)",
            subtitle: subtitle,
            sqlText: proc.request?.sqlText,
            fields: fields
        ))
    }

    func pushWaitInspector(ids: Set<SQLServerWaitStatDelta.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let wait = (snap.waitsDelta ?? []).first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let avgWait = wait.waitingTasksCountDelta > 0 ? wait.waitTimeMsDelta / wait.waitingTasksCountDelta : 0
        let signalPct = wait.waitTimeMsDelta > 0 ? Double(wait.signalWaitTimeMsDelta) / Double(wait.waitTimeMsDelta) * 100 : 0
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Wait Type", value: wait.waitType),
            .init(label: "Total Wait Time", value: "\(wait.waitTimeMsDelta) ms"),
            .init(label: "Signal Wait Time", value: "\(wait.signalWaitTimeMsDelta) ms"),
            .init(label: "Resource Wait Time", value: "\(wait.waitTimeMsDelta - wait.signalWaitTimeMsDelta) ms"),
            .init(label: "Signal %", value: String(format: "%.1f%%", signalPct)),
            .init(label: "Waiting Tasks", value: "\(wait.waitingTasksCountDelta)"),
            .init(label: "Avg Wait/Task", value: "\(avgWait) ms")
        ]
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: wait.waitType,
            subtitle: signalPct > 50 ? "CPU contention likely" : "Resource wait",
            fields: fields
        ))
    }

    func pushIOInspector(ids: Set<SQLServerFileIOStatDelta.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let io = (snap.fileIODelta ?? []).first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let avgReadSize = io.numReadsDelta > 0 ? io.bytesReadDelta / Int64(io.numReadsDelta) : 0
        let avgWriteSize = io.numWritesDelta > 0 ? io.bytesWrittenDelta / Int64(io.numWritesDelta) : 0
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Database", value: io.databaseName ?? "DB \(io.databaseId)"),
            .init(label: "File", value: io.fileName ?? "File \(io.fileId)"),
            .init(label: "Bytes Read", value: ByteCountFormatter.string(fromByteCount: io.bytesReadDelta, countStyle: .binary)),
            .init(label: "Bytes Written", value: ByteCountFormatter.string(fromByteCount: io.bytesWrittenDelta, countStyle: .binary)),
            .init(label: "Read Operations", value: "\(io.numReadsDelta)"),
            .init(label: "Write Operations", value: "\(io.numWritesDelta)"),
            .init(label: "Avg Read Size", value: ByteCountFormatter.string(fromByteCount: avgReadSize, countStyle: .binary)),
            .init(label: "Avg Write Size", value: ByteCountFormatter.string(fromByteCount: avgWriteSize, countStyle: .binary)),
            .init(label: "Read Stall", value: "\(io.ioStallReadMsDelta) ms"),
            .init(label: "Write Stall", value: "\(io.ioStallWriteMsDelta) ms")
        ]
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: io.databaseName ?? "Database \(io.databaseId)",
            subtitle: io.fileName ?? "File \(io.fileId)",
            fields: fields
        ))
    }

    func pushQueryInspector(ids: Set<SQLServerExpensiveQuery.ID>) {
        guard case .mssql(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let query = snap.expensiveQueries.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let avgWorker = query.executionCount > 0 ? query.totalWorkerTime / Int64(query.executionCount) : 0
        let avgElapsed = query.executionCount > 0 ? query.totalElapsedTime / Int64(query.executionCount) : 0
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Executions", value: "\(query.executionCount)"),
            .init(label: "Total Worker Time", value: formatMicroseconds(query.totalWorkerTime)),
            .init(label: "Total Elapsed Time", value: formatMicroseconds(query.totalElapsedTime)),
            .init(label: "Avg Worker Time", value: formatMicroseconds(avgWorker)),
            .init(label: "Avg Elapsed Time", value: formatMicroseconds(avgElapsed)),
            .init(label: "Max Worker Time", value: formatMicroseconds(query.maxWorkerTime)),
            .init(label: "Max Elapsed Time", value: formatMicroseconds(query.maxElapsedTime)),
            .init(label: "Logical Reads", value: "\(query.totalLogicalReads)"),
            .init(label: "Logical Writes", value: "\(query.totalLogicalWrites)")
        ]
        if let date = query.lastExecutionTime {
            fields.append(.init(label: "Last Execution", value: date.formatted(date: .abbreviated, time: .standard)))
        }
        if let hash = query.queryHashHex, !hash.isEmpty {
            fields.append(.init(label: "Query Hash", value: hash))
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Query",
            subtitle: "\(query.executionCount) executions \u{2022} \(formatMicroseconds(query.totalWorkerTime)) total",
            sqlText: query.sqlText,
            fields: fields
        ))
    }

    // MARK: - Formatting

    func formatMicroseconds(_ us: Int64) -> String {
        let ms = us / 1000
        if ms >= 60_000 { return String(format: "%.1f s", Double(ms) / 1000) }
        if ms >= 1000 { return String(format: "%.1f s", Double(ms) / 1000) }
        return "\(ms) ms"
    }
}
