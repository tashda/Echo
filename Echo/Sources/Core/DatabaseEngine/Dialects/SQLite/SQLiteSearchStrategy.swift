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
        let pattern = ObjectSearchProvider.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            let remaining = ObjectSearchProvider.QueryConstants.maxNameResults - aggregated.count
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
                let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
                if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            }
        }
        return aggregated
    }

    func searchColumns(query: String) async throws -> [SearchSidebarResult] {
        let pattern = query.lowercased()
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()

        for database in databases {
            if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            // Get all tables in this database
            let tablesSQL = """
            SELECT name FROM \(quoteDatabase(database)).sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
            ORDER BY name;
            """
            let tablesResult = try await session.simpleQuery(tablesSQL)
            let tableNames = tablesResult.rows.compactMap { $0.first ?? nil }

            for tableName in tableNames {
                if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
                let columnsSQL = "PRAGMA \(quoteDatabase(database)).table_info(\(quoteDatabase(tableName)))"
                let columnsResult = try await session.simpleQuery(columnsSQL)
                // PRAGMA table_info columns: cid, name, type, notnull, dflt_value, pk
                for row in columnsResult.rows {
                    guard row.count >= 3,
                          let colName = row[1],
                          colName.lowercased().contains(pattern) else { continue }
                    let dataType = row[2] ?? "TEXT"
                    let subtitle = "\(database).\(tableName)"
                    let payload = SearchSidebarResult.Payload.column(schema: database, table: tableName, column: colName)
                    aggregated.append(SearchSidebarResult(
                        category: .columns,
                        title: colName,
                        subtitle: subtitle,
                        metadata: dataType,
                        snippet: nil,
                        payload: payload
                    ))
                    if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
                }
            }
        }
        return aggregated
    }

    func searchIndexes(query: String) async throws -> [SearchSidebarResult] {
        let pattern = ObjectSearchProvider.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            let remaining = ObjectSearchProvider.QueryConstants.maxNameResults - aggregated.count
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
                let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
                if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            }
        }
        return aggregated
    }

    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] {
        let pattern = query.lowercased()
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()

        for database in databases {
            if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            let tablesSQL = """
            SELECT name FROM \(quoteDatabase(database)).sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
            ORDER BY name;
            """
            let tablesResult = try await session.simpleQuery(tablesSQL)
            let tableNames = tablesResult.rows.compactMap { $0.first ?? nil }

            for tableName in tableNames {
                if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
                let fkSQL = "PRAGMA \(quoteDatabase(database)).foreign_key_list(\(quoteDatabase(tableName)))"
                let fkResult = try await session.simpleQuery(fkSQL)
                // PRAGMA foreign_key_list columns: id, seq, table, from, to, on_update, on_delete, match
                for row in fkResult.rows {
                    guard row.count >= 5,
                          let refTable = row[2],
                          let fromCol = row[3],
                          let toCol = row[4] else { continue }
                    let fkDesc = "\(fromCol) -> \(refTable).\(toCol)"
                    guard fkDesc.lowercased().contains(pattern) || refTable.lowercased().contains(pattern) || fromCol.lowercased().contains(pattern) else { continue }
                    let subtitle = "\(database).\(tableName)"
                    let payload = SearchSidebarResult.Payload.foreignKey(schema: database, table: tableName, name: fkDesc)
                    aggregated.append(SearchSidebarResult(
                        category: .foreignKeys,
                        title: fkDesc,
                        subtitle: subtitle,
                        metadata: tableName,
                        snippet: nil,
                        payload: payload
                    ))
                    if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
                }
            }
        }
        return aggregated
    }

    private func searchMasterEntries(
        query: String,
        type: String,
        category: SearchSidebarCategory,
        objectType: SchemaObjectInfo.ObjectType
    ) async throws -> [SearchSidebarResult] {
        let pattern = ObjectSearchProvider.makeLikePattern(query)
        var aggregated: [SearchSidebarResult] = []
        let databases = await databaseNames()
        for database in databases {
            if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
            let remaining = ObjectSearchProvider.QueryConstants.maxNameResults - aggregated.count
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
                let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
                let payload = SearchSidebarResult.Payload.schemaObject(schema: database, name: name, type: objectType)
                aggregated.append(SearchSidebarResult(
                    category: category,
                    title: name,
                    subtitle: database,
                    metadata: nil,
                    snippet: snippet,
                    payload: payload
                ))
                if aggregated.count >= ObjectSearchProvider.QueryConstants.maxNameResults { break }
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
