import Foundation

struct SchemaSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let clause = context.sqlContext.clause
        let isObjectClause = Self.supportedClauses.contains(clause) || context.hasObjectKeywordContext
        guard isObjectClause else { return [] }

        let identifier = context.identifier
        if identifier.isTrailingDot,
           let last = identifier.precedingLowercased.last,
           context.catalog.schemas.contains(where: { $0.name.lowercased() == last }) {
            return []
        }
        if !identifier.precedingSegments.isEmpty && !identifier.lowercasePrefix.isEmpty {
            return []
        }

        let prefix = identifier.lowercasePrefix
        let selectedDatabase = context.request.selectedDatabase
        var results: [SQLCompletionSuggestion] = []

        for schema in context.catalog.schemas {
            if !prefix.isEmpty && !schema.name.lowercased().hasPrefix(prefix) {
                continue
            }

            var components = identifier.precedingSegments
            if let last = components.last,
               schema.name.lowercased().hasPrefix(last.lowercased()) {
                components.removeLast()
            }
            components.append(schema.name)

            let insertText = context.qualify(components) + "."
            let detail = selectedDatabase.map { "\($0).\(schema.name)" }

            results.append(SQLCompletionSuggestion(id: "schema|\(schema.name.lowercased())",
                                                   title: schema.name,
                                                   subtitle: selectedDatabase,
                                                   detail: detail,
                                                   insertText: insertText,
                                                   kind: .schema,
                                                   priority: 950))
        }

        return results
    }

    private static let supportedClauses: Set<SQLClause> = [
        .from, .joinTarget, .withCTE, .unknown
    ]
}
