import Foundation
import PostgresKit

extension ViewEditorViewModel {

    // MARK: - Load Existing View

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let pg = session.session as? PostgresSession else {
            errorMessage = "View editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        do {
            try await loadViewMetadata(pg: pg)
            try await loadViewComment(pg: pg)
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load view: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Metadata

    private func loadViewMetadata(pg: PostgresSession) async throws {
        if isMaterialized {
            try await loadMaterializedViewMetadata(pg: pg)
        } else {
            try await loadRegularViewMetadata(pg: pg)
        }
    }

    private func loadRegularViewMetadata(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                v.viewname,
                v.viewowner,
                v.definition
            FROM pg_views v
            WHERE v.schemaname = '\(escapeSQLIdentifier(schemaName))'
              AND v.viewname = '\(escapeSQLIdentifier(viewName))'
            LIMIT 1
            """

        let result = try await pg.simpleQuery(sql)
        guard let row = result.rows.first, row.count >= 3 else { return }

        owner = row[1] ?? ""
        definition = (row[2] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if definition.hasSuffix(";") {
            definition = String(definition.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func loadMaterializedViewMetadata(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                m.matviewname,
                m.matviewowner,
                m.definition
            FROM pg_matviews m
            WHERE m.schemaname = '\(escapeSQLIdentifier(schemaName))'
              AND m.matviewname = '\(escapeSQLIdentifier(viewName))'
            LIMIT 1
            """

        let result = try await pg.simpleQuery(sql)
        guard let row = result.rows.first, row.count >= 3 else { return }

        owner = row[1] ?? ""
        definition = (row[2] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if definition.hasSuffix(";") {
            definition = String(definition.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func loadViewComment(pg: PostgresSession) async throws {
        let relkind = isMaterialized ? "'m'" : "'v'"
        let sql = """
            SELECT obj_description(c.oid, 'pg_class')
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = '\(escapeSQLIdentifier(schemaName))'
              AND c.relname = '\(escapeSQLIdentifier(viewName))'
              AND c.relkind = \(relkind)
            LIMIT 1
            """
        let result = try await pg.simpleQuery(sql)
        if let row = result.rows.first, let comment = row[0], !comment.isEmpty {
            description = comment
        }
    }

    // MARK: - SQL Escaping

    private func escapeSQLIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
