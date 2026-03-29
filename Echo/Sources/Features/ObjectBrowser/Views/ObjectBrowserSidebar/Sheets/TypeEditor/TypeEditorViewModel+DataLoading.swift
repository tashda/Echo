import Foundation
import PostgresKit

extension TypeEditorViewModel {

    // MARK: - Load Existing Type

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Type editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        do {
            switch typeCategory {
            case .composite: try await loadComposite(pg: pg)
            case .enum: try await loadEnum(pg: pg)
            case .range: try await loadRange(pg: pg)
            case .domain: try await loadDomain(pg: pg)
            }
            try await loadTypeOwner(pg: pg)
            try await loadTypeComment(pg: pg)
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load type: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Composite

    private func loadComposite(pg: PostgresSession) async throws {
        let sql = """
            SELECT a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod)
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = '\(esc(schemaName))'
              AND c.relname = '\(esc(typeName))'
              AND a.attnum > 0
              AND NOT a.attisdropped
            ORDER BY a.attnum
            """
        let result = try await pg.simpleQuery(sql)
        attributes = result.rows.map { row in
            TypeAttributeDraft(name: row[0] ?? "", dataType: row[1] ?? "")
        }
        if attributes.isEmpty { attributes = [TypeAttributeDraft()] }
    }

    // MARK: - Enum

    private func loadEnum(pg: PostgresSession) async throws {
        let sql = """
            SELECT e.enumlabel
            FROM pg_enum e
            JOIN pg_type t ON t.oid = e.enumtypid
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = '\(esc(schemaName))'
              AND t.typname = '\(esc(typeName))'
            ORDER BY e.enumsortorder
            """
        let result = try await pg.simpleQuery(sql)
        enumValues = result.rows.map { row in
            EnumValueDraft(value: row[0] ?? "")
        }
        if enumValues.isEmpty { enumValues = [EnumValueDraft()] }
    }

    // MARK: - Range

    private func loadRange(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                pg_catalog.format_type(r.rngsubtype, NULL) AS subtype,
                COALESCE(opc.opcname, '') AS opclass,
                COALESCE(col.collname, '') AS collation
            FROM pg_range r
            JOIN pg_type t ON t.oid = r.rngtypid
            JOIN pg_namespace n ON n.oid = t.typnamespace
            LEFT JOIN pg_opclass opc ON opc.oid = r.rngsubopc
            LEFT JOIN pg_collation col ON col.oid = r.rngcollation
            WHERE n.nspname = '\(esc(schemaName))'
              AND t.typname = '\(esc(typeName))'
            LIMIT 1
            """
        let result = try await pg.simpleQuery(sql)
        if let row = result.rows.first {
            subtype = row[0] ?? ""
            subtypeOpClass = row[1] ?? ""
            collation = row[2] ?? ""
        }
    }

    // MARK: - Domain

    private func loadDomain(pg: PostgresSession) async throws {
        let sql = """
            SELECT
                pg_catalog.format_type(t.typbasetype, t.typtypmod) AS base_type,
                t.typdefault,
                t.typnotnull
            FROM pg_type t
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = '\(esc(schemaName))'
              AND t.typname = '\(esc(typeName))'
              AND t.typtype = 'd'
            LIMIT 1
            """
        let result = try await pg.simpleQuery(sql)
        if let row = result.rows.first {
            baseDataType = row[0] ?? ""
            defaultValue = row[1] ?? ""
            isNotNull = (row[2] ?? "false") == "true" || (row[2] ?? "f") == "t"
        }

        // Load constraints
        let constraintSQL = """
            SELECT conname, pg_catalog.pg_get_constraintdef(c.oid)
            FROM pg_constraint c
            JOIN pg_type t ON t.oid = c.contypid
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = '\(esc(schemaName))'
              AND t.typname = '\(esc(typeName))'
            ORDER BY conname
            """
        let cResult = try await pg.simpleQuery(constraintSQL)
        domainConstraints = cResult.rows.map { row in
            DomainConstraintDraft(
                name: row[0] ?? "",
                expression: (row[1] ?? "").replacingOccurrences(of: "CHECK ", with: "")
            )
        }
    }

    // MARK: - Owner

    private func loadTypeOwner(pg: PostgresSession) async throws {
        let sql = """
            SELECT pg_catalog.pg_get_userbyid(t.typowner)
            FROM pg_type t
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = '\(esc(schemaName))'
              AND t.typname = '\(esc(typeName))'
            LIMIT 1
            """
        let result = try await pg.simpleQuery(sql)
        if let row = result.rows.first {
            owner = row[0] ?? ""
        }
    }

    // MARK: - Comment

    private func loadTypeComment(pg: PostgresSession) async throws {
        let sql = """
            SELECT obj_description(t.oid, 'pg_type')
            FROM pg_type t
            JOIN pg_namespace n ON n.oid = t.typnamespace
            WHERE n.nspname = '\(esc(schemaName))'
              AND t.typname = '\(esc(typeName))'
            LIMIT 1
            """
        let result = try await pg.simpleQuery(sql)
        if let row = result.rows.first, let comment = row[0], !comment.isEmpty {
            description = comment
        }
    }

    // MARK: - Helpers

    private func esc(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
