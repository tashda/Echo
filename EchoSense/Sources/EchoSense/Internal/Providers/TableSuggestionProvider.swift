import Foundation

struct TableSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let clause = context.sqlContext.clause
        let isObjectClause = Self.supportedClauses.contains(clause) || context.hasObjectKeywordContext
        guard isObjectClause else { return [] }

        let identifier = context.identifier
        let prefix = identifier.lowercasePrefix

        let schemaFilterLower = identifier.precedingLowercased.last
        let exactSchema = schemaFilterLower.flatMap { filter in
            context.catalog.schemas.first(where: { $0.name.lowercased() == filter })
        }

        var candidateSchemas: [SQLSchema]
        if let exactSchema {
            candidateSchemas = [exactSchema]
        } else {
            candidateSchemas = context.catalog.schemas
        }

        var results: [SQLCompletionSuggestion] = []
        for schema in candidateSchemas {
            if exactSchema == nil,
               let filter = schemaFilterLower,
               !filter.isEmpty,
               !schema.name.lowercased().hasPrefix(filter) {
                continue
            }

            for object in schema.objects where Self.supportedObjectTypes.contains(object.type) {
                let objectLower = object.name.lowercased()
                if !prefix.isEmpty && !objectLower.hasPrefix(prefix) {
                    continue
                }

                var components = identifier.precedingSegments
                if components.isEmpty {
                    if let defaultSchema = context.defaultSchemaLowercased,
                       schema.name.lowercased() == defaultSchema {
                        components = []
                    } else {
                        components = [schema.name]
                    }
                } else if let lastIndex = components.indices.last,
                          schema.name.lowercased().hasPrefix(components[lastIndex].lowercased()) {
                    components[lastIndex] = schema.name
                }

                components.append(object.name)
                var insertText = context.qualify(components)

                if context.request.options.enableAliasShortcuts,
                   let alias = AliasGenerator.shortcut(for: object.name) {
                    insertText += " \(alias)"
                }

                let id = "object|\(schema.name.lowercased())|\(objectLower)"
                let priority = Self.priority(for: clause,
                                             schema: schema,
                                             defaultSchemaLower: context.defaultSchemaLowercased)

                results.append(SQLCompletionSuggestion(id: id,
                                                       title: object.name,
                                                       subtitle: schema.name,
                                                       detail: "\(schema.name).\(object.name)",
                                                       insertText: insertText,
                                                       kind: Self.kind(for: object.type),
                                                       priority: priority))
            }
        }

        return results
    }

    private static func priority(for clause: SQLClause,
                                 schema: SQLSchema,
                                 defaultSchemaLower: String?) -> Int {
        var base: Int
        switch clause {
        case .from, .joinTarget:
            base = 1300
        case .deleteWhere:
            base = 1200
        case .withCTE:
            base = 1100
        default:
            base = 1000
        }
        if let defaultSchemaLower,
           schema.name.lowercased() == defaultSchemaLower {
            base += 25
        }
        return base
    }

    private static func kind(for objectType: SQLObject.ObjectType) -> SQLCompletionSuggestion.Kind {
        switch objectType {
        case .table: return .table
        case .view: return .view
        case .materializedView: return .materializedView
        case .procedure: return .procedure
        case .function: return .function
        }
    }

    private static let supportedClauses: Set<SQLClause> = [
        .from, .joinTarget, .deleteWhere, .withCTE, .unknown
    ]

    private static let supportedObjectTypes: Set<SQLObject.ObjectType> = [
        .table, .view, .materializedView
    ]
}
