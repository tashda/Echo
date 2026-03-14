import Foundation
import SQLServerKit

struct MSSQLDatabaseSearchStrategy: DatabaseSearchStrategy {
    let session: DatabaseSession

    private var adapter: SQLServerSessionAdapter? {
        session as? SQLServerSessionAdapter
    }

    func searchTables(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchTables(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            SearchSidebarResult(
                category: .tables,
                title: result.name,
                subtitle: result.schema,
                metadata: nil,
                snippet: nil,
                payload: .schemaObject(schema: result.schema, name: result.name, type: .table)
            )
        }
    }

    func searchViews(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchViews(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            let snippet = result.definitionSnippet.flatMap {
                ObjectSearchProvider.makeSnippet(from: $0, matching: query)
            }
            return SearchSidebarResult(
                category: .views,
                title: result.name,
                subtitle: result.schema,
                metadata: nil,
                snippet: snippet,
                payload: .schemaObject(schema: result.schema, name: result.name, type: .view)
            )
        }
    }

    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult] {
        []
    }

    func searchFunctions(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchFunctions(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            let snippet = result.definitionSnippet.flatMap {
                ObjectSearchProvider.makeSnippet(from: $0, matching: query)
            }
            return SearchSidebarResult(
                category: .functions,
                title: result.name,
                subtitle: result.schema,
                metadata: result.schema,
                snippet: snippet,
                payload: .function(schema: result.schema, name: result.name)
            )
        }
    }

    func searchProcedures(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchProcedures(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            let snippet = result.definitionSnippet.flatMap {
                ObjectSearchProvider.makeSnippet(from: $0, matching: query)
            }
            return SearchSidebarResult(
                category: .procedures,
                title: result.name,
                subtitle: result.schema,
                metadata: result.schema,
                snippet: snippet,
                payload: .procedure(schema: result.schema, name: result.name)
            )
        }
    }

    func searchTriggers(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchTriggers(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            let snippet = ObjectSearchProvider.makeSnippet(from: result.events, matching: query)
            let metadata = [result.timing, result.events].filter { !$0.isEmpty }.joined(separator: " • ")
            return SearchSidebarResult(
                category: .triggers,
                title: result.name,
                subtitle: "\(result.schema).\(result.table)",
                metadata: metadata.isEmpty ? nil : metadata,
                snippet: snippet,
                payload: .trigger(schema: result.schema, table: result.table, name: result.name)
            )
        }
    }

    func searchColumns(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchColumns(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxColumnResults
        )
        return results.map { result in
            SearchSidebarResult(
                category: .columns,
                title: result.column,
                subtitle: "\(result.schema).\(result.table)",
                metadata: result.dataType.isEmpty ? nil : result.dataType,
                snippet: nil,
                payload: .column(schema: result.schema, table: result.table, column: result.column)
            )
        }
    }

    func searchIndexes(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchIndexes(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            let filter = result.filterDefinition ?? ""
            return SearchSidebarResult(
                category: .indexes,
                title: result.name,
                subtitle: "\(result.schema).\(result.table)",
                metadata: filter.isEmpty ? nil : filter,
                snippet: ObjectSearchProvider.makeSnippet(from: filter, matching: query),
                payload: .index(schema: result.schema, table: result.table, name: result.name)
            )
        }
    }

    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult] {
        guard let adapter else { return [] }
        let results = try await adapter.metadata.searchForeignKeys(
            query: query,
            database: adapter.database,
            limit: ObjectSearchProvider.QueryConstants.maxNameResults
        )
        return results.map { result in
            let metadata = [result.referencedSchema, result.referencedTable]
                .filter { !$0.isEmpty }
                .joined(separator: ".")
            return SearchSidebarResult(
                category: .foreignKeys,
                title: result.name,
                subtitle: "\(result.schema).\(result.table)",
                metadata: metadata.isEmpty ? nil : metadata,
                snippet: nil,
                payload: .foreignKey(schema: result.schema, table: result.table, name: result.name)
            )
        }
    }
}
