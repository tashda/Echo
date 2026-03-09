import Foundation

struct SnippetSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let allowedGroups = Self.allowedGroups(for: context.sqlContext.clause)
        guard !allowedGroups.isEmpty else { return [] }

        let prefix = context.identifier.lowercasePrefix
        let snippets = SQLSnippetCatalog.snippets(for: context.dialect)

        var results: [SQLCompletionSuggestion] = []
        for snippet in snippets where allowedGroups.contains(snippet.group) {
            let lowerTitle = snippet.title.lowercased()
            if !prefix.isEmpty && !lowerTitle.hasPrefix(prefix) {
                continue
            }
            results.append(SQLCompletionSuggestion(id: "snippet|\(snippet.id)",
                                                   title: snippet.title,
                                                   subtitle: "Snippet",
                                                   detail: snippet.detail,
                                                   insertText: snippet.insertText,
                                                   kind: .snippet,
                                                   priority: snippet.priority))
        }

        return results
    }

    private static func allowedGroups(for clause: SQLClause) -> Set<SQLSnippet.Group> {
        switch clause {
        case .selectList:
            return [.select, .json, .general]
        case .whereClause, .having, .joinCondition:
            return [.filter, .json, .general]
        case .from, .joinTarget:
            return [.join, .general]
        case .values, .updateSet:
            return [.modification, .general]
        default:
            return [.general]
        }
    }
}
