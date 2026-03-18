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
    var tableStats: [PostgresTableStat] = []
    var indexStats: [PostgresIndexStat] = []
    var isLoadingTables = false
    var isLoadingIndexes = false
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

    // MARK: - Table Stats

    func fetchTableStats(for database: String) async {
        isLoadingTables = true
        defer { isLoadingTables = false }
        do {
            let dbSession = try await session.sessionForDatabase(database)
            let sql = """
            SELECT schemaname, relname,
                   COALESCE(seq_scan, 0) AS seq_scan,
                   COALESCE(seq_tup_read, 0) AS seq_tup_read,
                   COALESCE(idx_scan, 0) AS idx_scan,
                   COALESCE(idx_tup_fetch, 0) AS idx_tup_fetch,
                   COALESCE(n_live_tup, 0) AS n_live_tup,
                   COALESCE(n_dead_tup, 0) AS n_dead_tup,
                   last_vacuum, last_autovacuum,
                   last_analyze, last_autoanalyze
            FROM pg_stat_user_tables
            ORDER BY n_dead_tup DESC
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

    private func parseTableStats(_ result: QueryResultSet) -> [PostgresTableStat] {
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
            return PostgresTableStat(
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
                lastAutoAnalyze: date(row, "last_autoanalyze")
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
