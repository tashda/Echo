import Foundation

protocol SQLKeywordProvider: Sendable {
    func keywords(for dialect: SQLDialect, context: SQLContext) -> [String]
}

struct DefaultKeywordProvider: SQLKeywordProvider {
    func keywords(for dialect: SQLDialect, context: SQLContext) -> [String] {
        var ordered: [String] = []

        switch context.clause {
        case .selectList:
            ordered.append(contentsOf: Self.selectKeywords)
        case .from, .joinTarget, .withCTE, .deleteWhere:
            ordered.append(contentsOf: Self.fromKeywords)
        case .whereClause, .joinCondition, .having:
            ordered.append(contentsOf: Self.filterKeywords)
        case .groupBy:
            ordered.append(contentsOf: Self.groupKeywords)
        case .orderBy:
            ordered.append(contentsOf: Self.orderKeywords)
        case .values:
            ordered.append(contentsOf: Self.valuesKeywords)
        case .updateSet:
            ordered.append(contentsOf: Self.updateKeywords)
        default:
            break
        }

        ordered.append(contentsOf: Self.commonKeywords)
        return DefaultKeywordProvider.unique(ordered)
    }

    private static let commonKeywords: [String] = [
        "select", "where", "update", "delete", "group", "order", "from", "by",
        "create", "table", "drop", "alter", "view", "execute", "procedure",
        "distinct", "insert", "join", "having", "limit", "offset", "values", "set", "into"
    ]

    private static let selectKeywords: [String] = [
        "select", "distinct", "case", "when", "then", "else", "end", "from", "where",
        "group", "order", "limit", "offset", "having", "union", "intersect", "except"
    ]

    private static let fromKeywords: [String] = [
        "from",
        "inner join",
        "left join",
        "right join",
        "full join",
        "left outer join",
        "right outer join",
        "full outer join",
        "cross join",
        "join",
        "on",
        "using",
        "where",
        "group",
        "partition",
        "lateral"
    ]

    private static let filterKeywords: [String] = [
        "where", "and", "or", "not", "exists", "in", "between", "like", "ilike",
        "is", "null", "coalesce"
    ]

    private static let groupKeywords: [String] = [
        "group", "by", "rollup", "cube", "grouping", "sets", "having"
    ]

    private static let orderKeywords: [String] = [
        "order", "by", "asc", "desc", "nulls", "first", "last"
    ]

    private static let valuesKeywords: [String] = [
        "values", "returning", "default"
    ]

    private static let updateKeywords: [String] = [
        "set", "from", "where", "returning"
    ]

    private static func unique(_ keywords: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for keyword in keywords {
            let lower = keyword.lowercased()
            if seen.insert(lower).inserted {
                result.append(lower)
            }
        }
        return result
    }
}
