import Foundation

struct SQLiteDatabaseSearchStrategy: DatabaseSearchStrategy {
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
        let pattern = DatabaseSearchProvider.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= DatabaseSearchProvider.QueryConstants.maxNameResults { break }
            let remaining = DatabaseSearchProvider.QueryConstants.maxNameResults - aggregated.count
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
                let snippet = DatabaseSearchProvider.makeSnippet(from: definition, matching: query)
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
                if aggregated.count >= DatabaseSearchProvider.QueryConstants.maxNameResults { break }
            }
        }
        return aggregated
    }

    func searchColumns(query: String) async throws -> [SearchSidebarResult] { [] }

    func searchIndexes(query: String) async throws -> [SearchSidebarResult] {
        let pattern = DatabaseSearchProvider.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= DatabaseSearchProvider.QueryConstants.maxNameResults { break }
            let remaining = DatabaseSearchProvider.QueryConstants.maxNameResults - aggregated.count
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
                let snippet = DatabaseSearchProvider.makeSnippet(from: definition, matching: query)
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
                if aggregated.count >= DatabaseSearchProvider.QueryConstants.maxNameResults { break }
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
        let pattern = DatabaseSearchProvider.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= DatabaseSearchProvider.QueryConstants.maxNameResults { break }
            let remaining = DatabaseSearchProvider.QueryConstants.maxNameResults - aggregated.count
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
                let snippet = DatabaseSearchProvider.makeSnippet(from: definition, matching: query)
                let payload = SearchSidebarResult.Payload.schemaObject(schema: database, name: name, type: objectType)
                aggregated.append(SearchSidebarResult(
                    category: category,
                    title: name,
                    subtitle: database,
                    metadata: nil,
                    snippet: snippet,
                    payload: payload
                ))
                if aggregated.count >= DatabaseSearchProvider.QueryConstants.maxNameResults { break }
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
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
