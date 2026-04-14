import Foundation

extension MaintenanceViewModel {

    func parseTableStats(_ result: QueryResultSet) -> [PostgresMaintenanceTableStat] {
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

    func parseIndexStats(_ result: QueryResultSet) -> [PostgresIndexStat] {
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
}
