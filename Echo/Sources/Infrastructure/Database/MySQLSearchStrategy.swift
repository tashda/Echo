import Foundation

struct MySQLDatabaseSearchStrategy: DatabaseSearchStrategy {
    private let session: DatabaseSession
    private let activeDatabase: String?
    private let excludedSchemas: Set<String> = [
        "information_schema",
        "mysql",
        "performance_schema",
        "sys"
    ]

    init(session: DatabaseSession, activeDatabase: String?) {
        self.session = session
        self.activeDatabase = activeDatabase?.isEmpty == false ? activeDatabase : nil
    }

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause(["table_name"], query: query)
        let sql = """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema NOT IN (\(excludedSchemasList))\(schemaFilter("table_schema"))
          AND (
            \(clause)
          )
        ORDER BY table_schema, table_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 2, let schema = row[0], let name = row[1] else { return nil }
            let payload = SearchSidebarResult.Payload.schemaObject(schema: schema, name: name, type: .table)
            return SearchSidebarResult(
                category: .tables,
                title: name,
                subtitle: schema,
                metadata: nil,
                snippet: nil,
                payload: payload
            )
        }
    }

    func searchViews(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause([
            "table_name",
            "view_definition"
        ], query: query)
        let sql = """
        SELECT table_schema, table_name, view_definition
        FROM information_schema.views
        WHERE table_schema NOT IN (\(excludedSchemasList))\(schemaFilter("table_schema"))
          AND (
            \(clause)
          )
        ORDER BY table_schema, table_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.schemaObject(schema: schema, name: name, type: .view)
            return SearchSidebarResult(
                category: .views,
                title: name,
                subtitle: schema,
                metadata: nil,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult] {
        []
    }

    func searchFunctions(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause([
            "routine_name",
            "routine_definition"
        ], query: query)
        let sql = """
        SELECT routine_schema, routine_name, routine_definition
        FROM information_schema.routines
        WHERE routine_type = 'FUNCTION'
          AND routine_schema NOT IN (\(excludedSchemasList))\(schemaFilter("routine_schema"))
          AND (
            \(clause)
          )
        ORDER BY routine_schema, routine_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.function(schema: schema, name: name)
            return SearchSidebarResult(
                category: .functions,
                title: name,
                subtitle: schema,
                metadata: schema,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchProcedures(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause([
            "routine_name",
            "routine_definition"
        ], query: query)
        let sql = """
        SELECT routine_schema, routine_name, routine_definition
        FROM information_schema.routines
        WHERE routine_type = 'PROCEDURE'
          AND routine_schema NOT IN (\(excludedSchemasList))\(schemaFilter("routine_schema"))
          AND (
            \(clause)
          )
        ORDER BY routine_schema, routine_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.procedure(schema: schema, name: name)
            return SearchSidebarResult(
                category: .procedures,
                title: name,
                subtitle: schema,
                metadata: schema,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchTriggers(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause([
            "trigger_name",
            "event_object_table",
            "action_statement"
        ], query: query)
        let sql = """
        SELECT trigger_schema, event_object_table, trigger_name, action_statement
        FROM information_schema.triggers
        WHERE trigger_schema NOT IN (\(excludedSchemasList))\(schemaFilter("trigger_schema"))
          AND (
            \(clause)
          )
        ORDER BY trigger_schema, trigger_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let definition = row.count > 3 ? (row[3] ?? "") : ""
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.trigger(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .triggers,
                title: name,
                subtitle: "\(schema).\(table)",
                metadata: table,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchColumns(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause(["column_name"], query: query)
        let sql = """
        SELECT table_schema, table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema NOT IN (\(excludedSchemasList))\(schemaFilter("table_schema"))
          AND (
            \(clause)
          )
        ORDER BY table_schema, table_name, ordinal_position
        LIMIT \(DatabaseSearchService.QueryConstants.maxColumnResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let column = row[2] else { return nil }
            let dataType = row[3] ?? ""
            let subtitle = "\(schema).\(table)"
            let metadata = dataType.isEmpty ? schema : dataType
            let payload = SearchSidebarResult.Payload.column(schema: schema, table: table, column: column)
            return SearchSidebarResult(
                category: .columns,
                title: column,
                subtitle: subtitle,
                metadata: metadata,
                snippet: nil,
                payload: payload
            )
        }
    }

    func searchIndexes(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause([
            "index_name",
            "table_name"
        ], query: query)
        let sql = """
        SELECT
            table_schema,
            table_name,
            index_name,
            GROUP_CONCAT(CONCAT(column_name, IF(collation = 'D', ' DESC', ' ASC')) ORDER BY seq_in_index SEPARATOR ', ') AS definition
        FROM information_schema.statistics
        WHERE table_schema NOT IN (\(excludedSchemasList))\(schemaFilter("table_schema"))
          AND (
            \(clause)
          )
        GROUP BY table_schema, table_name, index_name
        ORDER BY table_schema, index_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let definition = row[3] ?? ""
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.index(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .indexes,
                title: name,
                subtitle: "\(schema).\(table)",
                metadata: table,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] {
        let clause = containsClause([
            "constraint_name",
            "table_name",
            "referenced_table_name"
        ], query: query)
        let sql = """
        SELECT
            constraint_name,
            table_schema,
            table_name,
            referenced_table_schema,
            referenced_table_name,
            GROUP_CONCAT(column_name ORDER BY ordinal_position SEPARATOR ', ') AS column_list,
            GROUP_CONCAT(referenced_column_name ORDER BY ordinal_position SEPARATOR ', ') AS referenced_column_list
        FROM information_schema.key_column_usage
        WHERE referenced_table_name IS NOT NULL
          AND table_schema NOT IN (\(excludedSchemasList))\(schemaFilter("table_schema"))
          AND (
            \(clause)
          )
        GROUP BY
            constraint_name,
            table_schema,
            table_name,
            referenced_table_schema,
            referenced_table_name
        ORDER BY table_schema, table_name, constraint_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 7,
                  let name = row[0],
                  let schema = row[1],
                  let table = row[2]
            else { return nil }
            let referencedSchema = row[3] ?? ""
            let referencedTable = row[4] ?? ""
            let columns = row[5] ?? ""
            let referencedColumns = row[6] ?? ""
            let subtitle = "\(schema).\(table)"
            var snippetComponents: [String] = []
            if !columns.isEmpty {
                snippetComponents.append("Columns: \(columns)")
            }
            if !referencedTable.isEmpty {
                let reference = referencedSchema.isEmpty ? referencedTable : "\(referencedSchema).\(referencedTable)"
                snippetComponents.append("References: \(reference) (\(referencedColumns))")
            }
            let snippet = snippetComponents.isEmpty ? nil : snippetComponents.joined(separator: " | ")
            let payload = SearchSidebarResult.Payload.foreignKey(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .foreignKeys,
                title: name,
                subtitle: subtitle,
                metadata: referencedTable,
                snippet: snippet,
                payload: payload
            )
        }
    }

    private func schemaFilter(_ column: String) -> String {
        guard let activeDatabase else { return "" }
        let sanitized = escapeIdentifier(activeDatabase)
        return "\n          AND \(column) = '\(sanitized)'"
    }

    private var excludedSchemasList: String {
        excludedSchemas.map { "'\(escapeIdentifier($0))'" }.joined(separator: ", ")
    }

    private func escapeIdentifier(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "''")
    }

    private func containsClause(_ columns: [String], query: String) -> String {
        let lowered = query.lowercased()
        let sanitized = escapeLiteral(lowered)
        return columns.map { column in
            "LOCATE('\(sanitized)', LOWER(COALESCE(\(column), ''))) > 0"
        }
        .joined(separator: "\n          OR ")
    }

    private func escapeLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "''")
    }
}
