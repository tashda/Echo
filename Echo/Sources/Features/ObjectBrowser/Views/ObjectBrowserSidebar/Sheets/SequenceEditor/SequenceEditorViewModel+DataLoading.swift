import Foundation
import PostgresKit

extension SequenceEditorViewModel {

    // MARK: - Load Existing Sequence

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Sequence editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        do {
            try await loadSequenceMetadata(pg: pg)
            try await loadSequenceComment(pg: pg)
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load sequence: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Metadata

    private func loadSequenceMetadata(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                s.start_value::text,
                s.increment_by::text,
                s.min_value::text,
                s.max_value::text,
                s.cache_value::text,
                s.is_cycled,
                s.last_value::text,
                pg_catalog.pg_get_userbyid(c.relowner) AS owner
            FROM pg_sequences ps
            JOIN pg_class c ON c.relname = ps.sequencename
            JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = ps.schemaname
            LEFT JOIN \(quoteIdentifier(schemaName)).\(quoteIdentifier(sequenceName)) s ON TRUE
            WHERE ps.schemaname = '\(escapeSQLIdentifier(schemaName))'
              AND ps.sequencename = '\(escapeSQLIdentifier(sequenceName))'
            LIMIT 1
            """

        let result = try await pg.simpleQuery(sql)
        guard let row = result.rows.first, row.count >= 8 else {
            try await loadSequenceFromCatalog(pg: pg)
            return
        }

        startWith = row[0] ?? "1"
        incrementBy = row[1] ?? "1"
        minValue = row[2] ?? ""
        maxValue = row[3] ?? ""
        cache = row[4] ?? "1"
        cycle = (row[5] ?? "false") == "true" || (row[5] ?? "f") == "t"
        lastValue = row[6] ?? "—"
        owner = row[7] ?? ""
    }

    private func loadSequenceFromCatalog(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                ps.start_value::text,
                ps.increment::text,
                ps.min_value::text,
                ps.max_value::text,
                ps.cache_size::text,
                ps.cycle,
                ps.last_value::text,
                pg_catalog.pg_get_userbyid(c.relowner) AS owner
            FROM pg_sequences ps
            JOIN pg_class c ON c.relname = ps.sequencename
            JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = ps.schemaname
            WHERE ps.schemaname = '\(escapeSQLIdentifier(schemaName))'
              AND ps.sequencename = '\(escapeSQLIdentifier(sequenceName))'
            LIMIT 1
            """

        let result = try await pg.simpleQuery(sql)
        guard let row = result.rows.first, row.count >= 8 else { return }

        startWith = row[0] ?? "1"
        incrementBy = row[1] ?? "1"
        minValue = row[2] ?? ""
        maxValue = row[3] ?? ""
        cache = row[4] ?? "1"
        cycle = (row[5] ?? "false") == "true" || (row[5] ?? "f") == "t"
        lastValue = row[6] ?? "—"
        owner = row[7] ?? ""
    }

    private func loadSequenceComment(pg: PostgresSession) async throws {
        let sql = """
            SELECT obj_description(c.oid, 'pg_class')
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = '\(escapeSQLIdentifier(schemaName))'
              AND c.relname = '\(escapeSQLIdentifier(sequenceName))'
              AND c.relkind = 'S'
            LIMIT 1
            """
        let result = try await pg.simpleQuery(sql)
        if let row = result.rows.first, let comment = row[0], !comment.isEmpty {
            description = comment
        }
    }

    // MARK: - Helpers

    private func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func escapeSQLIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
