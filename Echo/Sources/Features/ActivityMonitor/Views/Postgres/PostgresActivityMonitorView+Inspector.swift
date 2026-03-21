import SwiftUI
import PostgresWire

extension PostgresActivityMonitorView {

    // MARK: - Inspector

    func pushSessionInspector(ids: Set<PostgresProcessInfo.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let proc = snap.processes.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "PID", value: "\(proc.pid)"),
            .init(label: "User", value: proc.userName ?? "\u{2014}"),
            .init(label: "Database", value: proc.databaseName ?? "\u{2014}"),
            .init(label: "Application", value: proc.applicationName ?? "\u{2014}"),
            .init(label: "Client", value: proc.clientAddress ?? "\u{2014}"),
            .init(label: "State", value: proc.state ?? "\u{2014}"),
            .init(label: "Backend Type", value: proc.backendType ?? "\u{2014}")
        ]
        if let wait = proc.waitEventType {
            fields.append(.init(label: "Wait Event", value: "\(wait): \(proc.waitEvent ?? "")"))
        }
        if let sql = proc.query, !sql.isEmpty {
            fields.append(.init(label: "Query", value: sql))
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Process \(proc.pid)",
            subtitle: proc.state ?? "unknown",
            fields: fields
        ))
    }

    func pushLockInspector(ids: Set<StickyLockState.StickyLock.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let key = ids.first else {
            environmentState.dataInspectorContent = nil
            return
        }
        let lock = snap.locks.first(where: {
            StickyLockState.StickyLock.compositeKey(pid: $0.pid, locktype: $0.locktype, relation: $0.relation, mode: $0.mode) == key
        })
        guard let lock else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "PID", value: "\(lock.pid)"),
            .init(label: "Database", value: lock.databaseName ?? "\u{2014}"),
            .init(label: "Lock Type", value: lock.locktype),
            .init(label: "Relation", value: lock.relation ?? "\u{2014}"),
            .init(label: "Mode", value: lock.mode),
            .init(label: "Granted", value: lock.granted ? "Yes" : "Waiting")
        ]
        if let blocking = lock.blockingPid {
            fields.append(.init(label: "Blocked By", value: "PID \(blocking)"))
        }
        if let dur = lock.waitDuration {
            fields.append(.init(label: "Wait Duration", value: String(format: "%.1fs", dur)))
        }
        if let sql = lock.query, !sql.isEmpty {
            fields.append(.init(label: "Query", value: sql))
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Lock \u{2022} PID \(lock.pid)",
            subtitle: "\(lock.mode) on \(lock.relation ?? lock.locktype)",
            fields: fields
        ))
    }

    func pushDBStatInspector(ids: Set<PostgresDatabaseStatDelta.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let stat = snap.databaseStatsDelta?.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let cacheHit = stat.cacheHitRatio.map { String(format: "%.1f%%", $0) } ?? "N/A"
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Database", value: stat.datname),
            .init(label: "Cache Hit Ratio", value: cacheHit),
            .init(label: "Commits", value: "\(stat.xact_commit_delta)"),
            .init(label: "Rollbacks", value: "\(stat.xact_rollback_delta)"),
            .init(label: "Blocks Read", value: "\(stat.blks_read_delta)"),
            .init(label: "Blocks Hit", value: "\(stat.blks_hit_delta)"),
            .init(label: "Tuples Inserted", value: "\(stat.tup_inserted_delta)"),
            .init(label: "Tuples Updated", value: "\(stat.tup_updated_delta)"),
            .init(label: "Tuples Deleted", value: "\(stat.tup_deleted_delta)"),
            .init(label: "Temp Files", value: "\(stat.temp_files_delta)"),
            .init(label: "Deadlocks", value: "\(stat.deadlocks_delta)")
        ]
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: stat.datname,
            subtitle: "Database Statistics (delta)",
            fields: fields
        ))
    }

    func pushOperationInspector(ids: Set<PostgresOperationProgress.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let op = snap.operationProgress.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        var fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "PID", value: "\(op.pid)"),
            .init(label: "Operation", value: op.operation),
            .init(label: "Phase", value: op.phase),
            .init(label: "Database", value: op.databaseName ?? "\u{2014}"),
            .init(label: "Object", value: op.relation ?? "\u{2014}")
        ]
        if let pct = op.progressPercent {
            fields.append(.init(label: "Progress", value: String(format: "%.0f%%", pct)))
        }
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "\(op.operation) \u{2022} PID \(op.pid)",
            subtitle: op.phase,
            fields: fields
        ))
    }

    func pushQueryInspector(ids: Set<PostgresExpensiveQuery.ID>) {
        guard case .postgres(let snap) = viewModel.latestSnapshot,
              let id = ids.first,
              let query = snap.expensiveQueries.first(where: { $0.id == id }) else {
            environmentState.dataInspectorContent = nil
            return
        }
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Query", value: query.query),
            .init(label: "Calls", value: "\(query.calls)"),
            .init(label: "Total Time", value: String(format: "%.1f ms", query.total_exec_time)),
            .init(label: "Mean Time", value: String(format: "%.2f ms", query.mean_exec_time)),
            .init(label: "Min Time", value: String(format: "%.2f ms", query.min_exec_time)),
            .init(label: "Max Time", value: String(format: "%.2f ms", query.max_exec_time)),
            .init(label: "Total Rows", value: "\(query.rows)")
        ]
        environmentState.dataInspectorContent = .databaseObject(DatabaseObjectInspectorContent(
            title: "Query \(query.queryid ?? 0)",
            subtitle: String(format: "%.1f ms total \u{2022} %d calls", query.total_exec_time, query.calls),
            fields: fields
        ))
    }
}
