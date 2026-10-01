import Foundation
import Testing
@testable import Echo

/// Round 37.4, HE0: the maintenance Health pages list what is wrong, worst first, each with its fix.
@Suite("Maintenance health findings")
struct MaintenanceHealthFindingsTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    @Test func aRecentFullBackupInSimpleRecoveryIsFine() {
        let findings = MaintenanceHealthFindings.sqlServer(status: "ONLINE", recoveryModel: "SIMPLE",
                                                           backups: [.init(type: "D", finished: daysAgo(1))],
                                                           fragmented: [], backupsKnown: true, now: now)
        #expect(findings.map(\.severity) == [.fine])
    }

    @Test func noFullBackupIsAProblemWithBackUpNow() {
        let findings = MaintenanceHealthFindings.sqlServer(status: "ONLINE", recoveryModel: "SIMPLE", backups: [],
                                                           fragmented: [], backupsKnown: true, now: now)
        #expect(findings.first?.id == "fullBackup")
        #expect(findings.first?.severity == .problem)
        #expect(findings.first?.fix == .backUpNow)
    }

    @Test func anUnreadHistorySaysNothingAboutBackups() {
        let findings = MaintenanceHealthFindings.sqlServer(status: "ONLINE", recoveryModel: "FULL", backups: [],
                                                           fragmented: [], backupsKnown: false, now: now)
        #expect(findings.map(\.id) == ["fine"])
    }

    @Test func anOldFullBackupAndNoLogBackupInFullRecovery() {
        let findings = MaintenanceHealthFindings.sqlServer(status: "ONLINE", recoveryModel: "FULL",
                                                           backups: [.init(type: "D", finished: daysAgo(9)), .init(type: "L", finished: daysAgo(2))],
                                                           fragmented: [], backupsKnown: true, now: now)
        #expect(findings.map(\.id) == ["fullBackup", "logBackup"])
        #expect(findings[0].title == "Last full backup 9 days ago")
    }

    @Test func onlyLargeFragmentedIndexesAskForARebuild() {
        let fragmented: [MaintenanceHealthFindings.Fragmented] = [
            .init(index: "IX_a", table: "dbo.a", percent: 64, pages: 5_000),
            .init(index: "IX_b", table: "dbo.b", percent: 80, pages: 10),
            .init(index: "IX_c", table: "dbo.c", percent: 12, pages: 9_000),
        ]
        let findings = MaintenanceHealthFindings.sqlServer(status: "ONLINE", recoveryModel: "SIMPLE",
                                                           backups: [.init(type: "D", finished: daysAgo(1))],
                                                           fragmented: fragmented, backupsKnown: true, now: now)
        #expect(findings.count == 1)
        #expect(findings[0].title == "1 index over 30% fragmented")
        #expect(findings[0].detail == "IX_a on dbo.a is 64%.")
        #expect(findings[0].fix == .rebuildIndexes)
    }

    @Test func problemsComeBeforeWarnings() {
        let findings = MaintenanceHealthFindings.sqlServer(
            status: "SUSPECT", recoveryModel: "SIMPLE", backups: [.init(type: "D", finished: daysAgo(1))],
            fragmented: [.init(index: "IX", table: "dbo.t", percent: 50, pages: 2_000)], backupsKnown: true, now: now)
        #expect(findings.map(\.severity) == [.problem, .warning])
    }

    private func table(_ name: String, live: Int64, dead: Int64) -> PostgresMaintenanceTableStat {
        PostgresMaintenanceTableStat(schemaName: "public", tableName: name, seqScan: 0, seqTupRead: 0, idxScan: 0, idxTupFetch: 0,
                                     nLiveTup: live, nDeadTup: dead, lastVacuum: nil, lastAutoVacuum: nil, lastAnalyze: nil,
                                     lastAutoAnalyze: nil, tableSizeBytes: 0, indexSizeBytes: 0, totalSizeBytes: 0, tableAge: 0)
    }

    @Test func postgresTablesWithManyDeadRowsNeedVacuum() {
        let tables = [table("orders", live: 50_000, dead: 40_000), table("small", live: 10, dead: 9), table("busy", live: 1_000_000, dead: 20_000)]
        #expect(MaintenanceHealthFindings.tablesNeedingVacuum(tables).map(\.tableName) == ["orders"])
        let findings = MaintenanceHealthFindings.postgres(health: nil, tables: tables)
        #expect(findings.map(\.id) == ["vacuum"])
        #expect(findings[0].fix == .vacuumTables)
    }

    @Test func postgresWithNothingWrongIsFine() {
        #expect(MaintenanceHealthFindings.postgres(health: nil, tables: [table("t", live: 100, dead: 1)]).map(\.severity) == [.fine])
    }
}
