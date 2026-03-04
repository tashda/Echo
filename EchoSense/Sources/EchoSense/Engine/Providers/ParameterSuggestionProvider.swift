import Foundation

struct ParameterSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        guard Self.supportedClauses.contains(context.sqlContext.clause) else { return [] }

        let prefix = context.identifier.lowercasePrefix
        let candidates = SQLParameterSuggester.parameterSuggestions(for: context.request.text,
                                                                    dialect: context.dialect)
        var results: [SQLCompletionSuggestion] = []

        for candidate in candidates {
            let lower = candidate.lowercased()
            if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                continue
            }
            results.append(SQLCompletionSuggestion(id: "parameter|\(lower)",
                                                   title: candidate,
                                                   subtitle: "Parameter",
                                                   detail: nil,
                                                   insertText: candidate,
                                                   kind: .parameter,
                                                   priority: 1300))
        }

        return results
    }

    private static let supportedClauses: Set<SQLClause> = [
        .whereClause, .having, .joinCondition, .values, .updateSet, .selectList
    ]
}
