import Foundation

struct PostgresDatabaseSearchStrategy: DatabaseSearchStrategy {
    let session: DatabaseSession

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.tables(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.views(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let subtitle = schema
            let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.materializedViews(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let subtitle = schema
            let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.functions(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.procedures(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 3, let schema = row[0], let name = row[1] else { return nil }
            let definition = row[2] ?? ""
            let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.triggers(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let definition = row[3] ?? ""
            let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.columns(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxColumnResults)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.indexes(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
        let result = try await session.simpleQuery(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let schema = row[0], let table = row[1], let name = row[2] else { return nil }
            let definition = row[3] ?? ""
            let subtitle = "\(schema).\(table)"
            let snippet = ObjectSearchProvider.makeSnippet(from: definition, matching: query)
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
        let pattern = PostgresSearchSQL.makeLikePattern(query)
        let sql = PostgresSearchSQL.foreignKeys(pattern: pattern, limit: ObjectSearchProvider.QueryConstants.maxNameResults)
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
