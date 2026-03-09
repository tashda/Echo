import Foundation

struct KeywordSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let keywords = context.keywordProvider.keywords(for: context.dialect,
                                                        context: context.sqlContext)
        let prefix = context.identifier.lowercasePrefix

        var seen = Set<String>()
        var results: [SQLCompletionSuggestion] = []

        for keyword in keywords {
            let lower = keyword.lowercased()
            guard seen.insert(lower).inserted else { continue }
            if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                continue
            }

            let (display, insert) = KeywordSuggestionProvider.casedKeyword(keyword,
                                                                           option: context.request.options.keywordCasing)
            let priority = KeywordSuggestionProvider.priority(for: context.sqlContext.clause)

            results.append(SQLCompletionSuggestion(id: "keyword|\(lower)",
                                                   title: display,
                                                   subtitle: nil,
                                                   detail: nil,
                                                   insertText: insert,
                                                   kind: .keyword,
                                                   priority: priority))
        }

        return results
    }

    private static func casedKeyword(_ keyword: String,
                                     option: SQLEngineOptions.KeywordCasing) -> (display: String, insert: String) {
        switch option {
        case .upper:
            let upper = keyword.uppercased()
            return (upper, upper)
        case .lower:
            let lower = keyword.lowercased()
            return (lower, lower)
        case .preserve:
            return (keyword.uppercased(), keyword)
        }
    }

    private static func priority(for clause: SQLClause) -> Int {
        switch clause {
        case .selectList, .whereClause, .having, .groupBy, .orderBy, .joinCondition:
            return 750
        case .from, .joinTarget, .deleteWhere:
            return 700
        default:
            return 650
        }
    }
}
