import Foundation

struct FunctionSuggestionProvider: SQLSuggestionProvider {
    func suggestions(in context: SQLProviderContext) -> [SQLCompletionSuggestion] {
        let clause = context.sqlContext.clause
        let isColumnClause = Self.supportedClauses.contains(clause) || context.hasColumnKeywordContext
        guard isColumnClause else { return [] }

        let prefix = context.identifier.lowercasePrefix
        var results: [SQLCompletionSuggestion] = []
        var seen = Set<String>()

        for schema in context.catalog.schemas {
            for object in schema.objects where object.type == .function {
                let lower = object.name.lowercased()
                if !prefix.isEmpty && !lower.hasPrefix(prefix) {
                    continue
                }
                let id = "function|\(schema.name.lowercased())|\(lower)"
                guard seen.insert(id).inserted else { continue }

                let priority = Self.priority(for: clause)
                results.append(SQLCompletionSuggestion(id: id,
                                                       title: object.name,
                                                       subtitle: schema.name,
                                                       detail: "Function \(schema.name).\(object.name)",
                                                       insertText: object.name + "(",
                                                       kind: .function,
                                                       priority: priority))
            }
        }

        return results
    }

    private static func priority(for clause: SQLClause) -> Int {
        switch clause {
        case .selectList:
            return 1200
        case .whereClause, .having, .joinCondition:
            return 1150
        default:
            return 1100
        }
    }

    private static let supportedClauses: Set<SQLClause> = [
        .selectList, .whereClause, .having, .groupBy, .orderBy, .joinCondition, .values, .updateSet
    ]
}
