import Foundation
import SwiftUI
import PostgresWire

@Observable
final class MaintenanceViewModel {
    let connectionID: UUID
    let connectionSessionID: UUID
    let databaseType: DatabaseType
    @ObservationIgnored let session: DatabaseSession

    var selectedDatabase: String?
    var databaseList: [String] = []
    var tableStats: [PostgresMaintenanceTableStat] = []
    var indexStats: [PostgresIndexStat] = []
    var healthStats: PostgresMaintenanceHealth?
    var isLoadingTables = false
    var isLoadingIndexes = false
    var isLoadingHealth = false
    var isInitialized = false

    init(
        session: DatabaseSession,
        connectionID: UUID,
        connectionSessionID: UUID,
        databaseType: DatabaseType,
        initialDatabase: String? = nil
    ) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
        self.databaseType = databaseType
        self.selectedDatabase = initialDatabase
    }

    // MARK: - Health Stats

    func fetchHealth(for database: String) async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }
        do {
            let dbSession = try await session.sessionForDatabase(database)
            let sql = """
            SELECT
                current_database() AS db_name,
                pg_database_size(current_database()) AS db_size,
                (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()) AS active_connections,
                current_setting('max_connections')::int AS max_connections,
                (SELECT age(datfrozenxid) FROM pg_database WHERE datname = current_database()) AS txid_age,
                (SELECT COALESCE(SUM(n_dead_tup), 0) FROM pg_stat_user_tables) AS dead_tuple_backlog,
                (SELECT count(*) FROM pg_stat_user_tables) AS table_count,
                (SELECT count(*) FROM pg_stat_user_indexes) AS index_count
            """
            let result = try await dbSession.simpleQuery(sql)

            // Cache hit from pg_stat_database
            let cacheSQL = """
            SELECT
                CASE WHEN blks_hit + blks_read = 0 THEN NULL
                     ELSE round(blks_hit::numeric / (blks_hit + blks_read) * 100, 2)
                END AS cache_hit_ratio
            FROM pg_stat_database
            WHERE datname = current_database()
            """
            let cacheResult = try await dbSession.simpleQuery(cacheSQL)

            // Oldest active transaction
            let oldestTxSQL = """
            SELECT extract(epoch FROM (now() - xact_start))::bigint AS oldest_tx_seconds
            FROM pg_stat_activity
            WHERE state = 'active' AND xact_start IS NOT NULL AND pid != pg_backend_pid()
            ORDER BY xact_start ASC
            LIMIT 1
            """
            let oldestTxResult = try await dbSession.simpleQuery(oldestTxSQL)

            // Background writer + checkpointer stats
            // PG17+ split checkpoint columns into pg_stat_checkpointer with renamed columns
            let bgwriterResult: QueryResultSet
            let pg17SQL = """
            SELECT c.num_timed AS checkpoints_timed,
                   c.num_requested AS checkpoints_req,
                   c.buffers_written AS buffers_checkpoint,
                   b.buffers_clean,
                   b.buffers_alloc AS buffers_backend
            FROM pg_stat_checkpointer c, pg_stat_bgwriter b
            """
            let legacySQL = """
            SELECT checkpoints_timed, checkpoints_req,
                   buffers_checkpoint, buffers_clean, buffers_backend
            FROM pg_stat_bgwriter
            """
            do {
                bgwriterResult = try await dbSession.simpleQuery(pg17SQL)
            } catch {
                bgwriterResult = try await dbSession.simpleQuery(legacySQL)
            }

            guard let row = result.rows.first else { return }
            let colNames = result.columns.map(\.name)
            func idx(_ name: String) -> Int? { colNames.firstIndex(of: name) }
            func str(_ name: String) -> String? {
                guard let i = idx(name), i < row.count else { return nil }
                return row[i]
            }

            let cacheHitRatio: Double? = if let cacheRow = cacheResult.rows.first, let val = cacheRow.first {
                Double(val ?? "")
            } else {
                nil
            }

            let oldestTxSeconds: Int64? = if let txRow = oldestTxResult.rows.first, let val = txRow.first {
                Int64(val ?? "")
            } else {
                nil
            }

            var bgwriter: PostgresMaintenanceHealth.BGWriterStats?
            if let bgRow = bgwriterResult.rows.first {
                let bgCols = bgwriterResult.columns.map(\.name)
                func bgIdx(_ name: String) -> Int? { bgCols.firstIndex(of: name) }
                func bgInt(_ name: String) -> Int64 {
                    guard let i = bgIdx(name), i < bgRow.count else { return 0 }
                    return Int64(bgRow[i] ?? "0") ?? 0
                }
                bgwriter = .init(
                    checkpointsTimed: bgInt("checkpoints_timed"),
                    checkpointsRequested: bgInt("checkpoints_req"),
                    buffersCheckpoint: bgInt("buffers_checkpoint"),
                    buffersClean: bgInt("buffers_clean"),
                    buffersBackend: bgInt("buffers_backend")
                )
            }

            healthStats = PostgresMaintenanceHealth(
                databaseName: str("db_name") ?? database,
                databaseSizeBytes: Int64(str("db_size") ?? "0") ?? 0,
                activeConnections: Int(str("active_connections") ?? "0") ?? 0,
                maxConnections: Int(str("max_connections") ?? "100") ?? 100,
                transactionIdAge: Int64(str("txid_age") ?? "0") ?? 0,
                cacheHitRatio: cacheHitRatio,
                deadTupleBacklog: Int64(str("dead_tuple_backlog") ?? "0") ?? 0,
                tableCount: Int(str("table_count") ?? "0") ?? 0,
                indexCount: Int(str("index_count") ?? "0") ?? 0,
                oldestTransactionSeconds: oldestTxSeconds,
                bgwriterStats: bgwriter
            )
        } catch {
            healthStats = nil
        }
    }

    // MARK: - Table Stats

    func fetchTableStats(for database: String) async {
        isLoadingTables = true
        defer { isLoadingTables = false }
        do {
            let dbSession = try await session.sessionForDatabase(database)
            let sql = """
            SELECT s.schemaname, s.relname,
                   COALESCE(s.seq_scan, 0) AS seq_scan,
                   COALESCE(s.seq_tup_read, 0) AS seq_tup_read,
                   COALESCE(s.idx_scan, 0) AS idx_scan,
                   COALESCE(s.idx_tup_fetch, 0) AS idx_tup_fetch,
                   COALESCE(s.n_live_tup, 0) AS n_live_tup,
                   COALESCE(s.n_dead_tup, 0) AS n_dead_tup,
                   s.last_vacuum, s.last_autovacuum,
                   s.last_analyze, s.last_autoanalyze,
                   pg_table_size(s.relid) AS table_size,
                   pg_indexes_size(s.relid) AS index_size,
                   pg_total_relation_size(s.relid) AS total_size,
                   age(c.relfrozenxid) AS table_age
            FROM pg_stat_user_tables s
            JOIN pg_class c ON c.oid = s.relid
            ORDER BY s.n_dead_tup DESC
            LIMIT 50
            """
            let result = try await dbSession.simpleQuery(sql)
            tableStats = parseTableStats(result)
        } catch {
            tableStats = []
        }
    }

    // MARK: - Index Stats

    func fetchIndexStats(for database: String) async {
        isLoadingIndexes = true
        defer { isLoadingIndexes = false }
        do {
            let dbSession = try await session.sessionForDatabase(database)
            let sql = """
            SELECT s.schemaname, s.relname AS table_name,
                   s.indexrelname AS index_name,
                   pg_relation_size(s.indexrelid) AS index_size,
                   pg_relation_size(s.relid) AS table_size,
                   COALESCE(s.idx_scan, 0) AS idx_scan,
                   COALESCE(s.idx_tup_read, 0) AS idx_tup_read,
                   COALESCE(s.idx_tup_fetch, 0) AS idx_tup_fetch,
                   i.indisunique,
                   i.indisprimary,
                   i.indisvalid,
                   am.amname AS index_type,
                   pg_get_indexdef(s.indexrelid) AS index_definition
            FROM pg_stat_user_indexes s
            JOIN pg_index i ON i.indexrelid = s.indexrelid
            JOIN pg_class c ON c.oid = s.indexrelid
            JOIN pg_am am ON am.oid = c.relam
            ORDER BY pg_relation_size(s.indexrelid) DESC
            LIMIT 200
            """
            let result = try await dbSession.simpleQuery(sql)
            indexStats = parseIndexStats(result)
        } catch {
            indexStats = []
        }
    }

    // MARK: - Maintenance Operations

    func vacuumTable(database: String, schema: String, table: String, full: Bool = false, analyze: Bool = false) async throws {
        let dbSession = try await session.sessionForDatabase(database)
        try await dbSession.vacuumTable(schema: schema, table: table, full: full, analyze: analyze)
    }

    func analyzeTable(database: String, schema: String, table: String) async throws {
        let dbSession = try await session.sessionForDatabase(database)
        try await dbSession.analyzeTable(schema: schema, table: table)
    }

    func reindexTable(database: String, schema: String, table: String) async throws {
        let dbSession = try await session.sessionForDatabase(database)
        try await dbSession.reindexTable(schema: schema, table: table)
    }

    func reindexIndex(database: String, schema: String, indexName: String) async throws {
        let dbSession = try await session.sessionForDatabase(database)
        let quotedSchema = schema.replacingOccurrences(of: "\"", with: "\"\"")
        let quotedIndex = indexName.replacingOccurrences(of: "\"", with: "\"\"")
        _ = try await dbSession.simpleQuery("REINDEX INDEX \"\(quotedSchema)\".\"\(quotedIndex)\"")
    }

    func reindex(_ index: PostgresIndexStat) async throws {
        guard let db = selectedDatabase else { return }
        try await reindexIndex(database: db, schema: index.schemaName, indexName: index.indexName)
        await fetchIndexStats(for: db)
    }

    func dropIndex(_ index: PostgresIndexStat) async throws {
        guard let db = selectedDatabase else { return }
        let dbSession = try await session.sessionForDatabase(db)
        try await dbSession.dropIndex(schema: index.schemaName, name: index.indexName)
        await fetchIndexStats(for: db)
    }

    func refresh() async {
        guard let db = selectedDatabase else { return }
        await fetchTableStats(for: db)
        await fetchIndexStats(for: db)
    }

    // MARK: - Parsing

    private func parseTableStats(_ result: QueryResultSet) -> [PostgresMaintenanceTableStat] {
        let colNames = result.columns.map(\.name)
        func idx(_ name: String) -> Int? { colNames.firstIndex(of: name) }
        func str(_ row: [String?], _ name: String) -> String? {
            guard let i = idx(name) else { return nil }
            return row[i]
        }
        func int64(_ row: [String?], _ name: String) -> Int64 {
            Int64(str(row, name) ?? "0") ?? 0
        }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        func date(_ row: [String?], _ name: String) -> Date? {
            guard let s = str(row, name) else { return nil }
            let normalized = s.replacingOccurrences(of: " ", with: "T")
            return dateFormatter.date(from: normalized) ?? fallbackFormatter.date(from: normalized)
        }
        return result.rows.compactMap { row in
            guard let schema = str(row, "schemaname"), let name = str(row, "relname") else { return nil }
            return PostgresMaintenanceTableStat(
                schemaName: schema,
                tableName: name,
                seqScan: int64(row, "seq_scan"),
                seqTupRead: int64(row, "seq_tup_read"),
                idxScan: int64(row, "idx_scan"),
                idxTupFetch: int64(row, "idx_tup_fetch"),
                nLiveTup: int64(row, "n_live_tup"),
                nDeadTup: int64(row, "n_dead_tup"),
                lastVacuum: date(row, "last_vacuum"),
                lastAutoVacuum: date(row, "last_autovacuum"),
                lastAnalyze: date(row, "last_analyze"),
                lastAutoAnalyze: date(row, "last_autoanalyze"),
                tableSizeBytes: int64(row, "table_size"),
                indexSizeBytes: int64(row, "index_size"),
                totalSizeBytes: int64(row, "total_size"),
                tableAge: int64(row, "table_age")
            )
        }
    }

    private func parseIndexStats(_ result: QueryResultSet) -> [PostgresIndexStat] {
        let colNames = result.columns.map(\.name)
        func idx(_ name: String) -> Int? { colNames.firstIndex(of: name) }
        func str(_ row: [String?], _ name: String) -> String? {
            guard let i = idx(name) else { return nil }
            return row[i]
        }
        func int64(_ row: [String?], _ name: String) -> Int64 {
            Int64(str(row, name) ?? "0") ?? 0
        }
        func bool(_ row: [String?], _ name: String) -> Bool {
            str(row, name) == "t" || str(row, name) == "true"
        }
        return result.rows.compactMap { row in
            guard let schema = str(row, "schemaname"),
                  let table = str(row, "table_name"),
                  let index = str(row, "index_name") else { return nil }
            let indexSize = int64(row, "index_size")
            let tableSize = int64(row, "table_size")
            let indexToTablePct = tableSize > 0 ? Double(indexSize) / Double(tableSize) * 100.0 : 0
            return PostgresIndexStat(
                indexName: index,
                tableName: table,
                schemaName: schema,
                indexSizeBytes: indexSize,
                tableSizeBytes: tableSize,
                indexToTablePct: indexToTablePct,
                idxScan: int64(row, "idx_scan"),
                idxTupRead: int64(row, "idx_tup_read"),
                idxTupFetch: int64(row, "idx_tup_fetch"),
                isUnique: bool(row, "indisunique"),
                isPrimary: bool(row, "indisprimary"),
                isValid: bool(row, "indisvalid"),
                indexType: str(row, "index_type") ?? "btree",
                definition: str(row, "index_definition") ?? ""
            )
        }
    }

    func estimatedMemoryUsageBytes() -> Int {
        256 * 1024
    }
}

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
