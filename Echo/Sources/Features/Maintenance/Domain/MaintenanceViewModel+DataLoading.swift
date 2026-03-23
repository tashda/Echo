import Foundation
import PostgresWire

extension MaintenanceViewModel {

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
}
