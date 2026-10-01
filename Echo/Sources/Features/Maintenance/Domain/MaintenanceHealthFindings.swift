import Foundation
import SQLServerKit

/// What the maintenance Health pages find (round 37.4, HE0), from the figures they already load.
nonisolated enum MaintenanceHealthFindings {
    /// A backup as the findings need it: its kind (D full, L log, …) and when it finished.
    struct Backup: Sendable {
        let type: String
        let finished: Date?
    }

    /// A fragmented index as the findings need it.
    struct Fragmented: Sendable {
        let index: String
        let table: String
        let percent: Double
        let pages: Int64
    }

    static let fullBackupMaxAgeDays = 7
    static let logBackupMaxAgeHours = 24
    static let rebuildFragmentation = 30.0
    static let minimumPages: Int64 = 1_000
    static let vacuumDeadTuples: Int64 = 10_000
    static let vacuumDeadShare = 0.2

    /// SQL Server: the database's state, its backups and fragmented indexes.
    static func sqlServer(status: String?, recoveryModel: String?, backups: [Backup],
                          fragmented: [Fragmented], backupsKnown: Bool, now: Date = Date()) -> [HealthFinding] {
        var findings: [HealthFinding] = []
        if let status, status.uppercased() != "ONLINE" {
            findings.append(.init(id: "status", severity: .problem, title: "The database is \(status.lowercased())",
                                  detail: "It must be online before anything else can be checked."))
        }
        if backupsKnown {
            let fullBackups = backups.filter { $0.type == "D" }.compactMap(\.finished)
            if let last = fullBackups.max() {
                let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
                if days > fullBackupMaxAgeDays {
                    findings.append(.init(id: "fullBackup", severity: .problem, title: "Last full backup \(days) days ago",
                                          detail: "Finished \(last.formatted(date: .abbreviated, time: .shortened)).", fix: .backUpNow))
                }
            } else {
                findings.append(.init(id: "fullBackup", severity: .problem, title: "No full backup on record",
                                      detail: "msdb has no full backup of this database.", fix: .backUpNow))
            }
            if recoveryModel?.uppercased() == "FULL" {
                let lastLog = backups.filter { $0.type == "L" }.compactMap(\.finished).max()
                if lastLog.map({ now.timeIntervalSince($0) > Double(logBackupMaxAgeHours) * 3_600 }) ?? true {
                    findings.append(.init(id: "logBackup", severity: .warning, title: "No log backup in the last day",
                                          detail: "In the full recovery model the log grows until it is backed up.", fix: .backUpNow))
                }
            }
        }
        let worth = fragmented.filter { $0.percent >= rebuildFragmentation && $0.pages >= minimumPages }
        if let worst = worth.max(by: { $0.percent < $1.percent }) {
            let others = worth.count - 1
            findings.append(.init(id: "fragmentation", severity: .warning,
                                  title: worth.count == 1 ? "1 index over 30% fragmented" : "\(worth.count) indexes over 30% fragmented",
                                  detail: "\(worst.index) on \(worst.table) is \(Int(worst.percent))%"
                                      + (others > 0 ? ", and \(others) more" : "") + ".",
                                  fix: .rebuildIndexes))
        }
        return HealthFinding.sorted(findings.isEmpty ? [allFine] : findings)
    }

    /// PostgreSQL: dead rows waiting for vacuum, old transactions, connections and the cache.
    static func postgres(health: PostgresMaintenanceHealth?, tables: [PostgresMaintenanceTableStat]) -> [HealthFinding] {
        var findings: [HealthFinding] = []
        let needVacuum = tablesNeedingVacuum(tables)
        if let worst = needVacuum.max(by: { $0.nDeadTup < $1.nDeadTup }) {
            findings.append(.init(id: "vacuum", severity: .warning,
                                  title: needVacuum.count == 1 ? "1 table needs vacuum" : "\(needVacuum.count) tables need vacuum",
                                  detail: "\(worst.schemaName).\(worst.tableName) has \(worst.nDeadTup.formatted()) dead rows.", fix: .vacuumTables))
        }
        if let health {
            if let seconds = health.oldestTransactionSeconds, seconds > 3_600 {
                findings.append(.init(id: "oldestTransaction", severity: .problem, title: "A transaction open for \(seconds / 3_600) h",
                                      detail: "It holds back vacuum on every table. Find it in Activity Monitor."))
            }
            if health.maxConnections > 0, health.connectionUsagePercent > 80 {
                findings.append(.init(id: "connections", severity: .warning, title: "\(Int(health.connectionUsagePercent))% of connections in use",
                                      detail: "\(health.activeConnections) of \(health.maxConnections)."))
            }
            if let ratio = health.cacheHitRatio, ratio < 90 {
                findings.append(.init(id: "cache", severity: .warning, title: "Cache hit ratio \(Int(ratio))%",
                                      detail: "Below 90% most reads go to disk; shared_buffers may be too small."))
            }
        }
        return HealthFinding.sorted(findings.isEmpty ? [allFine] : findings)
    }

    static func tablesNeedingVacuum(_ tables: [PostgresMaintenanceTableStat]) -> [PostgresMaintenanceTableStat] {
        tables.filter { table in
            let total = table.nLiveTup + table.nDeadTup
            return table.nDeadTup >= vacuumDeadTuples && total > 0 && Double(table.nDeadTup) / Double(total) >= vacuumDeadShare
        }
    }

    static func fragmentedToRebuild(_ indexes: [SQLServerIndexFragmentation]) -> [SQLServerIndexFragmentation] {
        indexes.filter { $0.fragmentationPercent >= rebuildFragmentation && $0.pageCount >= minimumPages }
    }

    private static let allFine = HealthFinding(id: "fine", severity: .fine, title: "Nothing to fix", detail: "Echo found no problems in what it checks.")
}
