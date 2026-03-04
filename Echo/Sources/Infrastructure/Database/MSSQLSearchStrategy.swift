import Foundation

struct MSSQLDatabaseSearchStrategy: DatabaseSearchStrategy {
    let session: DatabaseSession

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            TABLE_SCHEMA,
            TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
          AND LOWER(TABLE_NAME) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
        ORDER BY TABLE_SCHEMA, TABLE_NAME;
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            TABLE_SCHEMA,
            TABLE_NAME,
            COALESCE(VIEW_DEFINITION, '') AS VIEW_DEFINITION
        FROM INFORMATION_SCHEMA.VIEWS
        WHERE (
            LOWER(TABLE_NAME) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
            OR LOWER(COALESCE(VIEW_DEFINITION, '')) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
        )
        ORDER BY TABLE_SCHEMA, TABLE_NAME;
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            ROUTINE_SCHEMA,
            ROUTINE_NAME,
            COALESCE(ROUTINE_DEFINITION, '') AS ROUTINE_DEFINITION
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_TYPE = 'FUNCTION'
          AND (
            LOWER(ROUTINE_NAME) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
            OR LOWER(COALESCE(ROUTINE_DEFINITION, '')) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
          )
        ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME;
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            s.name AS schema_name,
            p.name AS procedure_name,
            COALESCE(sm.definition, '') AS definition
        FROM sys.procedures AS p
        JOIN sys.schemas AS s ON p.schema_id = s.schema_id
        LEFT JOIN sys.sql_modules AS sm ON p.object_id = sm.object_id
        WHERE p.is_ms_shipped = 0
          AND (
            LOWER(p.name) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
            OR LOWER(COALESCE(sm.definition, '')) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
          )
        ORDER BY s.name, p.name;
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            s.name AS schema_name,
            t.name AS table_name,
            tr.name AS trigger_name,
            STUFF((
                SELECT ', ' + ev.type_desc
                FROM sys.trigger_events AS ev
                WHERE ev.object_id = tr.object_id
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 2, '') AS event_list,
            CASE WHEN tr.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS timing
        FROM sys.triggers AS tr
        JOIN sys.tables AS t ON tr.parent_id = t.object_id
        JOIN sys.schemas AS s ON t.schema_id = s.schema_id
        WHERE (
            LOWER(tr.name) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
            OR LOWER(t.name) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
        )
        ORDER BY s.name, tr.name;
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 5, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let events = row[3] ?? ""
            let timing = row[4] ?? ""
            let snippet = DatabaseSearchService.makeSnippet(from: events, matching: query)
            let metadata = [timing, events].filter { !$0.isEmpty }.joined(separator: " • ")
            let payload = SearchSidebarResult.Payload.trigger(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .triggers,
                title: name,
                subtitle: "\(schema).\(table)",
                metadata: metadata.isEmpty ? nil : metadata,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchColumns(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxColumnResults)
            TABLE_SCHEMA,
            TABLE_NAME,
            COLUMN_NAME,
            DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE LOWER(COLUMN_NAME) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
        ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let column = row[2] else { return nil }
            let dataType = row[3] ?? ""
            let payload = SearchSidebarResult.Payload.column(schema: schema, table: table, column: column)
            return SearchSidebarResult(
                category: .columns,
                title: column,
                subtitle: "\(schema).\(table)",
                metadata: dataType.isEmpty ? nil : dataType,
                snippet: nil,
                payload: payload
            )
        }
    }

    func searchIndexes(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            s.name AS schema_name,
            t.name AS table_name,
            i.name AS index_name,
            COALESCE(i.filter_definition, '') AS filter_definition
        FROM sys.indexes AS i
        JOIN sys.tables AS t ON i.object_id = t.object_id
        JOIN sys.schemas AS s ON t.schema_id = s.schema_id
        WHERE i.is_primary_key = 0
          AND i.[type] <> 0
          AND (
            LOWER(i.name) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
            OR LOWER(t.name) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
          )
        ORDER BY s.name, i.name;
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let filter = row[3] ?? ""
            let payload = SearchSidebarResult.Payload.index(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .indexes,
                title: name,
                subtitle: "\(schema).\(table)",
                metadata: filter.isEmpty ? nil : filter,
                snippet: DatabaseSearchService.makeSnippet(from: filter, matching: query),
                payload: payload
            )
        }
    }

    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            s.name AS schema_name,
            t.name AS table_name,
            fk.name AS constraint_name,
            OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema,
            OBJECT_NAME(fk.referenced_object_id) AS referenced_table
        FROM sys.foreign_keys AS fk
        JOIN sys.tables AS t ON fk.parent_object_id = t.object_id
        JOIN sys.schemas AS s ON t.schema_id = s.schema_id
        WHERE LOWER(fk.name) LIKE LOWER('%\(pattern)%') ESCAPE '\\'
        ORDER BY s.name, fk.name;
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 5, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let refSchema = row[3] ?? ""
            let refTable = row[4] ?? ""
            let metadata = [refSchema, refTable].filter { !$0.isEmpty }.joined(separator: ".")
            let payload = SearchSidebarResult.Payload.foreignKey(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .foreignKeys,
                title: name,
                subtitle: "\(schema).\(table)",
                metadata: metadata.isEmpty ? nil : metadata,
                snippet: nil,
                payload: payload
            )
        }
    }
}
