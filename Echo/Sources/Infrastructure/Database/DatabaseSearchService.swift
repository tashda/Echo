import Foundation

struct DatabaseSearchService {
    fileprivate struct QueryConstants {
        static let maxNameResults = 50
        static let maxColumnResults = 120
    }

    private let strategy: any DatabaseSearchStrategy

    init(session: DatabaseSession, databaseType: DatabaseType, activeDatabase: String?) {
        self.strategy = DatabaseSearchService.makeStrategy(
            session: session,
            databaseType: databaseType,
            activeDatabase: activeDatabase
        )
    }

    func search(
        query: String,
        categories: Set<SearchSidebarCategory>
    ) async throws -> [SearchSidebarResult] {
        var aggregated: [SearchSidebarResult] = []
        var firstError: Error?
        var didSucceed = false

        if categories.contains(.tables) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchTables(query: query)
            }
        }

        if categories.contains(.views) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchViews(query: query)
            }
        }

        if categories.contains(.materializedViews) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchMaterializedViews(query: query)
            }
        }

        if categories.contains(.functions) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchFunctions(query: query)
            }
        }

        if categories.contains(.procedures) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchProcedures(query: query)
            }
        }

        if categories.contains(.triggers) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchTriggers(query: query)
            }
        }

        if categories.contains(.columns) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchColumns(query: query)
            }
        }

        if categories.contains(.indexes) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchIndexes(query: query)
            }
        }

        if categories.contains(.foreignKeys) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchForeignKeys(query: query)
            }
        }

        if !didSucceed, let error = firstError {
            throw error
        }

        return aggregated.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.category.displayName.localizedCaseInsensitiveCompare(rhs.category.displayName) == .orderedAscending
        }
    }

    private func appendResults(
        into aggregated: inout [SearchSidebarResult],
        didSucceed: inout Bool,
        firstError: inout Error?,
        fetch: () async throws -> [SearchSidebarResult]
    ) async {
        do {
            let results = try await fetch()
            aggregated.append(contentsOf: results)
            didSucceed = didSucceed || !results.isEmpty
        } catch {
            if firstError == nil {
                firstError = error
            }
        }
    }

    static func makeLikePattern(_ query: String) -> String {
        var sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
        sanitized = sanitized.replacingOccurrences(of: "%", with: "\\%")
        sanitized = sanitized.replacingOccurrences(of: "_", with: "\\_")
        sanitized = sanitized.replacingOccurrences(of: "'", with: "''")
        return sanitized
    }

    static func makeSnippet(from text: String, matching query: String, radius: Int = 80) -> String? {
        guard !text.isEmpty else { return nil }
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        guard let range = lowercasedText.range(of: lowercasedQuery) else { return nil }
        let lowerBound = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let upperBound = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        var snippet = String(text[lowerBound..<upperBound])
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "\r", with: " ")
        while snippet.contains("  ") {
            snippet = snippet.replacingOccurrences(of: "  ", with: " ")
        }
        snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if lowerBound > text.startIndex {
            snippet = "..." + snippet
        }
        if upperBound < text.endIndex {
            snippet += "..."
        }
        return snippet
    }

    private static func makeStrategy(
        session: DatabaseSession,
        databaseType: DatabaseType,
        activeDatabase: String?
    ) -> any DatabaseSearchStrategy {
        switch databaseType {
        case .postgresql:
            return PostgresDatabaseSearchStrategy(session: session)
        case .mysql:
            return MySQLDatabaseSearchStrategy(session: session, activeDatabase: activeDatabase)
        case .sqlite:
            return SQLiteDatabaseSearchStrategy(session: session)
        case .microsoftSQL:
            return MSSQLDatabaseSearchStrategy(session: session)
        }
    }
}

private protocol DatabaseSearchStrategy {
    func searchTables(query: String) async throws -> [SearchSidebarResult]
    func searchViews(query: String) async throws -> [SearchSidebarResult]
    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult]
    func searchFunctions(query: String) async throws -> [SearchSidebarResult]
    func searchProcedures(query: String) async throws -> [SearchSidebarResult]
    func searchTriggers(query: String) async throws -> [SearchSidebarResult]
    func searchColumns(query: String) async throws -> [SearchSidebarResult]
    func searchIndexes(query: String) async throws -> [SearchSidebarResult]
    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult]
}

private struct UnsupportedDatabaseSearchStrategy: DatabaseSearchStrategy {
    func searchTables(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchViews(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchFunctions(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchProcedures(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchTriggers(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchColumns(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchIndexes(query: String) async throws -> [SearchSidebarResult] { [] }
    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] { [] }
}

private struct SQLiteDatabaseSearchStrategy: DatabaseSearchStrategy {
    let session: DatabaseSession

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        try await searchMasterEntries(query: query, type: "table", category: .tables, objectType: .table)
    }

    func searchViews(query: String) async throws -> [SearchSidebarResult] {
        try await searchMasterEntries(query: query, type: "view", category: .views, objectType: .view)
    }

    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult] { [] }

    func searchFunctions(query: String) async throws -> [SearchSidebarResult] { [] }

    func searchProcedures(query: String) async throws -> [SearchSidebarResult] { [] }

    func searchTriggers(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= DatabaseSearchService.QueryConstants.maxNameResults { break }
            let remaining = DatabaseSearchService.QueryConstants.maxNameResults - aggregated.count
            let sql = """
            SELECT name, tbl_name, sql
            FROM \(quoteDatabase(database)).sqlite_master
            WHERE type = 'trigger'
              AND name LIKE '%\(pattern)%' ESCAPE '\\'
            ORDER BY name
            LIMIT \(remaining);
            """
            let result = try await session.simpleQuery(sql)
            for row in result.rows {
                guard row.count >= 2, let name = row[0], let table = row[1] else { continue }
                let definition = row.count > 2 ? (row[2] ?? "") : ""
                let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
                let subtitle = "\(database).\(table)"
                let payload = SearchSidebarResult.Payload.trigger(schema: database, table: table, name: name)
                aggregated.append(SearchSidebarResult(
                    category: .triggers,
                    title: name,
                    subtitle: subtitle,
                    metadata: table,
                    snippet: snippet,
                    payload: payload
                ))
                if aggregated.count >= DatabaseSearchService.QueryConstants.maxNameResults { break }
            }
        }
        return aggregated
    }

    func searchColumns(query: String) async throws -> [SearchSidebarResult] { [] }

    func searchIndexes(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= DatabaseSearchService.QueryConstants.maxNameResults { break }
            let remaining = DatabaseSearchService.QueryConstants.maxNameResults - aggregated.count
            let sql = """
            SELECT name, tbl_name, COALESCE(sql, '')
            FROM \(quoteDatabase(database)).sqlite_master
            WHERE type = 'index'
              AND name NOT LIKE 'sqlite_%'
              AND name LIKE '%\(pattern)%' ESCAPE '\\'
            ORDER BY name
            LIMIT \(remaining);
            """
            let result = try await session.simpleQuery(sql)
            for row in result.rows {
                guard row.count >= 2, let name = row[0], let table = row[1] else { continue }
                let definition = row.count > 2 ? (row[2] ?? "") : ""
                let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
                let subtitle = "\(database).\(table)"
                let payload = SearchSidebarResult.Payload.index(schema: database, table: table, name: name)
                aggregated.append(SearchSidebarResult(
                    category: .indexes,
                    title: name,
                    subtitle: subtitle,
                    metadata: table,
                    snippet: snippet,
                    payload: payload
                ))
                if aggregated.count >= DatabaseSearchService.QueryConstants.maxNameResults { break }
            }
        }
        return aggregated
    }

    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] { [] }

    private func searchMasterEntries(
        query: String,
        type: String,
        category: SearchSidebarCategory,
        objectType: SchemaObjectInfo.ObjectType
    ) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= DatabaseSearchService.QueryConstants.maxNameResults { break }
            let remaining = DatabaseSearchService.QueryConstants.maxNameResults - aggregated.count
            let sql = """
            SELECT name, COALESCE(sql, '')
            FROM \(quoteDatabase(database)).sqlite_master
            WHERE type = '\(type)'
              AND name NOT LIKE 'sqlite_%'
              AND name LIKE '%\(pattern)%' ESCAPE '\\'
            ORDER BY name
            LIMIT \(remaining);
            """
            let result = try await session.simpleQuery(sql)
            for row in result.rows {
                guard let name = row.first ?? nil else { continue }
                let definition = row.count > 1 ? (row[1] ?? "") : ""
                let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
                let payload = SearchSidebarResult.Payload.schemaObject(schema: database, name: name, type: objectType)
                aggregated.append(SearchSidebarResult(
                    category: category,
                    title: name,
                    subtitle: database,
                    metadata: nil,
                    snippet: snippet,
                    payload: payload
                ))
                if aggregated.count >= DatabaseSearchService.QueryConstants.maxNameResults { break }
            }
        }
        return aggregated
    }

    private func databaseNames() async -> [String] {
        if let schemas = try? await session.listSchemas(), !schemas.isEmpty {
            return schemas
        }
        return ["main"]
    }

    private func quoteDatabase(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct MSSQLDatabaseSearchStrategy: DatabaseSearchStrategy {
    let session: DatabaseSession

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT TOP \(DatabaseSearchService.QueryConstants.maxNameResults)
            TABLE_SCHEMA,
            TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
          AND LOWER(TABLE_NAME) LIKE LOWER('%\(pattern)%') ESCAPE '\\\\'
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

private struct PostgresDatabaseSearchStrategy: DatabaseSearchStrategy {
    let session: DatabaseSession

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema NOT IN ('pg_catalog', 'information_schema')
          AND table_name ILIKE '%\(pattern)%' ESCAPE '\\'
        ORDER BY table_schema, table_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard
                row.count >= 2,
                let schema = row[0],
                let name = row[1]
            else { return nil }
            let subtitle = schema
            let payload = SearchSidebarResult.Payload.schemaObject(schema: schema, name: name, type: .table)
            return SearchSidebarResult(
                category: .tables,
                title: name,
                subtitle: subtitle,
                metadata: nil,
                snippet: nil,
                payload: payload
            )
        }
    }

    func searchViews(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT table_schema, table_name, view_definition
        FROM information_schema.views
        WHERE (
            table_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(view_definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
        )
        ORDER BY table_schema, table_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let subtitle = schema
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.schemaObject(schema: schema, name: name, type: .view)
            return SearchSidebarResult(
                category: .views,
                title: name,
                subtitle: subtitle,
                metadata: nil,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT schemaname, matviewname, definition
        FROM pg_matviews
        WHERE (
            matviewname ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
        )
        ORDER BY schemaname, matviewname
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let subtitle = schema
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.schemaObject(schema: schema, name: name, type: .materializedView)
            return SearchSidebarResult(
                category: .materializedViews,
                title: name,
                subtitle: subtitle,
                metadata: nil,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchFunctions(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT routine_schema, routine_name, routine_definition
        FROM information_schema.routines
        WHERE routine_type = 'FUNCTION'
          AND routine_schema NOT IN ('pg_catalog', 'information_schema')
          AND (
            routine_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(routine_definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT routine_schema, routine_name, routine_definition
        FROM information_schema.routines
        WHERE routine_type = 'PROCEDURE'
          AND routine_schema NOT IN ('pg_catalog', 'information_schema')
          AND (
            routine_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(routine_definition, '') ILIKE '%\(pattern)%' ESCAPE '\\'
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT trigger_schema, event_object_table, trigger_name, action_statement
        FROM information_schema.triggers
        WHERE trigger_schema NOT IN ('pg_catalog', 'information_schema')
          AND (
            trigger_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR event_object_table ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(action_statement, '') ILIKE '%\(pattern)%' ESCAPE '\\'
          )
        ORDER BY trigger_schema, trigger_name
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let definition = row[3] ?? ""
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT table_schema, table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
          AND column_name ILIKE '%\(pattern)%' ESCAPE '\\'
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
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
          AND (
            indexname ILIKE '%\(pattern)%' ESCAPE '\\'
            OR tablename ILIKE '%\(pattern)%' ESCAPE '\\'
            OR COALESCE(indexdef, '') ILIKE '%\(pattern)%' ESCAPE '\\'
          )
        ORDER BY schemaname, indexname
        LIMIT \(DatabaseSearchService.QueryConstants.maxNameResults);
        """
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let definition = row[3] ?? ""
            let subtitle = "\(schema).\(table)"
            let snippet = DatabaseSearchService.makeSnippet(from: definition, matching: query)
            let payload = SearchSidebarResult.Payload.index(schema: schema, table: table, name: name)
            return SearchSidebarResult(
                category: .indexes,
                title: name,
                subtitle: subtitle,
                metadata: table,
                snippet: snippet,
                payload: payload
            )
        }
    }

    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchService.makeLikePattern(query)
        let sql = """
        WITH fk_data AS (
            SELECT
                tc.constraint_name,
                tc.table_schema,
                tc.table_name,
                ccu.table_schema AS referenced_schema,
                ccu.table_name AS referenced_table,
                string_agg(kcu.column_name ORDER BY kcu.ordinal_position) AS column_list,
                string_agg(ccu.column_name ORDER BY kcu.ordinal_position) AS referenced_column_list
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
             AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
              ON ccu.constraint_name = tc.constraint_name
             AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
            GROUP BY
                tc.constraint_name,
                tc.table_schema,
                tc.table_name,
                ccu.table_schema,
                ccu.table_name
        )
        SELECT
            constraint_name,
            table_schema,
            table_name,
            referenced_schema,
            referenced_table,
            column_list,
            referenced_column_list
        FROM fk_data
        WHERE (
            constraint_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR table_name ILIKE '%\(pattern)%' ESCAPE '\\'
            OR referenced_table ILIKE '%\(pattern)%' ESCAPE '\\'
        )
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
}

private struct MySQLDatabaseSearchStrategy: DatabaseSearchStrategy {
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
        return "\n          AND \(column) = '\(escapeIdentifier(activeDatabase))'"
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
