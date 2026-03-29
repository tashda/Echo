import Foundation
import PostgresKit

extension TriggerEditorViewModel {

    // MARK: - Load Existing Trigger

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Trigger editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        do {
            try await loadTriggerMetadata(pg: pg)
            try await loadTriggerComment(pg: pg)
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load trigger: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Metadata

    private func loadTriggerMetadata(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                t.tgname,
                pg_catalog.pg_get_triggerdef(t.oid) AS definition,
                t.tgenabled,
                p.proname AS function_name,
                n2.nspname AS function_schema
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            JOIN pg_proc p ON p.oid = t.tgfoid
            JOIN pg_namespace n2 ON n2.oid = p.pronamespace
            WHERE n.nspname = '\(escapeSQLIdentifier(schemaName))'
              AND c.relname = '\(escapeSQLIdentifier(tableName))'
              AND t.tgname = '\(escapeSQLIdentifier(triggerName))'
              AND NOT t.tgisinternal
            LIMIT 1
            """

        let result = try await pg.simpleQuery(sql)
        guard let row = result.rows.first, row.count >= 5 else { return }

        let definition = row[1] ?? ""
        let enabledFlag = row[2] ?? "O"
        let funcName = row[3] ?? ""
        let funcSchema = row[4] ?? ""

        functionName = funcSchema == schemaName ? funcName : "\(funcSchema).\(funcName)"
        isEnabled = enabledFlag == "O"

        parseTriggerDefinition(definition)
    }

    private func parseTriggerDefinition(_ definition: String) {
        let upper = definition.uppercased()

        if upper.contains("BEFORE") {
            timing = .before
        } else if upper.contains("INSTEAD OF") {
            timing = .insteadOf
        } else {
            timing = .after
        }

        onInsert = upper.contains("INSERT")
        onUpdate = upper.contains("UPDATE")
        onDelete = upper.contains("DELETE")
        onTruncate = upper.contains("TRUNCATE")

        if upper.contains("FOR EACH STATEMENT") {
            forEach = .statement
        } else {
            forEach = .row
        }

        if let whenRange = definition.range(of: "WHEN (", options: .caseInsensitive) {
            let afterWhen = definition[whenRange.upperBound...]
            var depth = 1
            var endIndex = afterWhen.startIndex
            for i in afterWhen.indices {
                if afterWhen[i] == "(" { depth += 1 }
                else if afterWhen[i] == ")" {
                    depth -= 1
                    if depth == 0 { endIndex = i; break }
                }
            }
            whenCondition = String(afterWhen[afterWhen.startIndex..<endIndex])
        }
    }

    private func loadTriggerComment(pg: PostgresSession) async throws {
        let sql = """
            SELECT obj_description(t.oid, 'pg_trigger')
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = '\(escapeSQLIdentifier(schemaName))'
              AND c.relname = '\(escapeSQLIdentifier(tableName))'
              AND t.tgname = '\(escapeSQLIdentifier(triggerName))'
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
