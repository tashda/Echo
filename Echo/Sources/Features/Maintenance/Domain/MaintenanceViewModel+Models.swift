import Foundation
import SwiftUI

// MARK: - Health Model

struct PostgresMaintenanceHealth {
    let databaseName: String
    let databaseSizeBytes: Int64
    let activeConnections: Int
    let maxConnections: Int
    let transactionIdAge: Int64
    let cacheHitRatio: Double?
    let deadTupleBacklog: Int64
    let tableCount: Int
    let indexCount: Int
    let oldestTransactionSeconds: Int64?
    let bgwriterStats: BGWriterStats?

    struct BGWriterStats {
        let checkpointsTimed: Int64
        let checkpointsRequested: Int64
        let buffersCheckpoint: Int64
        let buffersClean: Int64
        let buffersBackend: Int64
    }

    var connectionUsagePercent: Double {
        maxConnections > 0 ? Double(activeConnections) / Double(maxConnections) * 100 : 0
    }

    /// Transaction ID age as a percentage of the 2B wraparound limit
    var txidAgePercent: Double {
        Double(transactionIdAge) / 2_000_000_000 * 100
    }

    var txidSeverity: TxidSeverity {
        if transactionIdAge > 1_500_000_000 { return .critical }
        if transactionIdAge > 500_000_000 { return .warning }
        return .healthy
    }

    enum TxidSeverity {
        case healthy, warning, critical
    }
}

// MARK: - Enhanced Table Stat Model

struct PostgresMaintenanceTableStat: Identifiable, Sendable {
    var id: String { "\(schemaName).\(tableName)" }

    let schemaName: String
    let tableName: String
    let seqScan: Int64
    let seqTupRead: Int64
    let idxScan: Int64
    let idxTupFetch: Int64
    let nLiveTup: Int64
    let nDeadTup: Int64
    let lastVacuum: Date?
    let lastAutoVacuum: Date?
    let lastAnalyze: Date?
    let lastAutoAnalyze: Date?
    let tableSizeBytes: Int64
    let indexSizeBytes: Int64
    let totalSizeBytes: Int64
    let tableAge: Int64

    var deadTupleRatio: Double {
        nLiveTup > 0 ? Double(nDeadTup) / Double(nLiveTup) : 0
    }

    /// True if table age exceeds 500M (25% of wraparound limit)
    var isAgingRisk: Bool {
        tableAge > 500_000_000
    }
}

// MARK: - Index Stat Model

struct PostgresIndexStat: Identifiable, Sendable {
    var id: String { "\(schemaName).\(tableName).\(indexName)" }

    let indexName: String
    let tableName: String
    let schemaName: String
    let indexSizeBytes: Int64
    let tableSizeBytes: Int64
    let indexToTablePct: Double
    let idxScan: Int64
    let idxTupRead: Int64
    let idxTupFetch: Int64
    let isUnique: Bool
    let isPrimary: Bool
    let isValid: Bool
    let indexType: String
    let definition: String

    enum Kind: String, Sendable {
        case primary
        case unique
        case index

        var displayInfo: (icon: String, color: Color) {
            switch self {
            case .primary: return ("key.fill", .orange)
            case .unique: return ("lock.fill", .blue)
            case .index: return ("list.bullet.indent", .secondary)
            }
        }
    }

    var kind: Kind {
        if isPrimary { return .primary }
        if isUnique { return .unique }
        return .index
    }

    var kindLabel: String {
        if isPrimary { return "PK" }
        if isUnique { return "UQ" }
        return "IX"
    }

    var isUnused: Bool {
        !isPrimary && idxScan == 0
    }

    var isBloated: Bool {
        indexToTablePct > 200 && indexSizeBytes > 1_048_576
    }
}
