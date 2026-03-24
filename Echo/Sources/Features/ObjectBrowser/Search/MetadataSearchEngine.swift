import Foundation

/// Searches cached DatabaseStructure metadata across all active sessions.
/// This is Tier 1 search — pure in-memory, no SQL queries, instant results.
@MainActor
enum MetadataSearchEngine {

    /// Maximum results per category per database to avoid flooding.
    private static let maxResultsPerCategoryPerDatabase = 50
    private static let maxColumnResults = 120

    static func search(
        query: String,
        scope: SearchScope,
        sessions: [ConnectionSession],
        categories: Set<SearchSidebarCategory>
    ) -> [GlobalSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedQuery.count >= 2 else { return [] }

        var results: [GlobalSearchResult] = []

        for session in sessions {
            guard scope.includes(sessionID: session.id) else { continue }
            guard let structure = session.databaseStructure else { continue }

            let serverName = session.connection.connectionName.isEmpty
                ? session.connection.host
                : session.connection.connectionName
            let databaseType = session.connection.databaseType

            for database in structure.databases {
                guard scope.includes(sessionID: session.id, databaseName: database.name) else { continue }

                let dbResults = searchDatabase(
                    database: database,
                    query: normalizedQuery,
                    categories: categories,
                    connectionSessionID: session.id,
                    serverName: serverName,
                    databaseType: databaseType
                )
                results.append(contentsOf: dbResults)
            }
        }

        results.sort { lhs, rhs in
            if lhs.serverName != rhs.serverName {
                return lhs.serverName.localizedCaseInsensitiveCompare(rhs.serverName) == .orderedAscending
            }
            if lhs.databaseName != rhs.databaseName {
                return lhs.databaseName.localizedCaseInsensitiveCompare(rhs.databaseName) == .orderedAscending
            }
            if lhs.category != rhs.category {
                return lhs.category.displayName < rhs.category.displayName
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return results
    }

    private static func searchDatabase(
        database: DatabaseInfo,
        query: String,
        categories: Set<SearchSidebarCategory>,
        connectionSessionID: UUID,
        serverName: String,
        databaseType: DatabaseType
    ) -> [GlobalSearchResult] {
        var results: [GlobalSearchResult] = []

        let allObjects = database.schemas.flatMap { schema in
            schema.objects.map { (schema: schema.name, object: $0) }
        }

        if categories.contains(.tables) {
            let matched = allObjects
                .filter { $0.object.type == .table && matches($0.object, query: query) }
                .prefix(maxResultsPerCategoryPerDatabase)
            for item in matched {
                results.append(makeResult(
                    object: item.object, schema: item.schema,
                    category: .tables,
                    payload: .schemaObject(schema: item.schema, name: item.object.name, type: .table),
                    connectionSessionID: connectionSessionID, serverName: serverName,
                    databaseName: database.name, databaseType: databaseType
                ))
            }
        }

        if categories.contains(.views) {
            let matched = allObjects
                .filter { ($0.object.type == .view || $0.object.type == .materializedView) && matches($0.object, query: query) }
                .prefix(maxResultsPerCategoryPerDatabase)
            for item in matched {
                let category: SearchSidebarCategory = item.object.type == .materializedView ? .materializedViews : .views
                results.append(makeResult(
                    object: item.object, schema: item.schema,
                    category: category,
                    payload: .schemaObject(schema: item.schema, name: item.object.name, type: item.object.type),
                    connectionSessionID: connectionSessionID, serverName: serverName,
                    databaseName: database.name, databaseType: databaseType
                ))
            }
        }

        if categories.contains(.functions) {
            let matched = allObjects
                .filter { $0.object.type == .function && matches($0.object, query: query) }
                .prefix(maxResultsPerCategoryPerDatabase)
            for item in matched {
                results.append(makeResult(
                    object: item.object, schema: item.schema,
                    category: .functions,
                    payload: .function(schema: item.schema, name: item.object.name),
                    connectionSessionID: connectionSessionID, serverName: serverName,
                    databaseName: database.name, databaseType: databaseType
                ))
            }
        }

        if categories.contains(.procedures) {
            let matched = allObjects
                .filter { $0.object.type == .procedure && matches($0.object, query: query) }
                .prefix(maxResultsPerCategoryPerDatabase)
            for item in matched {
                results.append(makeResult(
                    object: item.object, schema: item.schema,
                    category: .procedures,
                    payload: .procedure(schema: item.schema, name: item.object.name),
                    connectionSessionID: connectionSessionID, serverName: serverName,
                    databaseName: database.name, databaseType: databaseType
                ))
            }
        }

        if categories.contains(.triggers) {
            let matched = allObjects
                .filter { $0.object.type == .trigger && matches($0.object, query: query) }
                .prefix(maxResultsPerCategoryPerDatabase)
            for item in matched {
                results.append(makeResult(
                    object: item.object, schema: item.schema,
                    category: .triggers,
                    payload: .trigger(schema: item.schema, table: item.object.triggerTable ?? "", name: item.object.name),
                    connectionSessionID: connectionSessionID, serverName: serverName,
                    databaseName: database.name, databaseType: databaseType
                ))
            }
        }

        if categories.contains(.columns) {
            var columnCount = 0
            for item in allObjects where columnCount < maxColumnResults {
                guard item.object.type == .table || item.object.type == .view || item.object.type == .materializedView else { continue }
                for column in item.object.columns where columnCount < maxColumnResults {
                    if column.name.lowercased().contains(query) {
                        results.append(GlobalSearchResult(
                            connectionSessionID: connectionSessionID,
                            serverName: serverName,
                            databaseName: database.name,
                            databaseType: databaseType,
                            category: .columns,
                            title: column.name,
                            subtitle: "\(item.schema).\(item.object.name)",
                            metadata: column.dataType,
                            snippet: nil,
                            payload: .column(schema: item.schema, table: item.object.name, column: column.name)
                        ))
                        columnCount += 1
                    }
                }
            }
        }

        return results
    }

    private static func matches(_ object: SchemaObjectInfo, query: String) -> Bool {
        object.name.lowercased().contains(query)
            || object.fullName.lowercased().contains(query)
            || object.schema.lowercased().contains(query)
    }

    private static func makeResult(
        object: SchemaObjectInfo,
        schema: String,
        category: SearchSidebarCategory,
        payload: SearchSidebarResult.Payload,
        connectionSessionID: UUID,
        serverName: String,
        databaseName: String,
        databaseType: DatabaseType
    ) -> GlobalSearchResult {
        GlobalSearchResult(
            connectionSessionID: connectionSessionID,
            serverName: serverName,
            databaseName: databaseName,
            databaseType: databaseType,
            category: category,
            title: object.fullName,
            subtitle: schema,
            metadata: object.comment,
            snippet: nil,
            payload: payload
        )
    }
}
