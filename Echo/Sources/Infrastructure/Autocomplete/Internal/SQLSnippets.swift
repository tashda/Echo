import Foundation

struct SQLSnippet {
    enum Group {
        case select
        case filter
        case join
        case modification
        case json
        case general
    }

    let id: String
    let title: String
    let detail: String?
    let insertText: String
    let group: Group
    let priority: Int
}

enum SQLSnippetCatalog {
    static func snippets(for dialect: SQLDialect) -> [SQLSnippet] {
        switch dialect {
        case .postgresql:
            return Self.postgresSnippets
        case .mysql:
            return Self.mysqlSnippets
        case .sqlite:
            return Self.sqliteSnippets
        case .microsoftSQL:
            return Self.sqlServerSnippets
        }
    }

    private static let postgresSnippets: [SQLSnippet] = [
        SQLSnippet(id: "pg.case",
                   title: "CASE WHEN … END",
                   detail: "Conditional expression",
                   insertText: """
CASE
    WHEN <#condition#> THEN <#result#>
    ELSE <#fallback#>
END
""",
                   group: .select,
                   priority: 1000),
        SQLSnippet(id: "pg.coalesce",
                   title: "COALESCE(value, fallback)",
                   detail: "Use fallback value when NULL",
                   insertText: "COALESCE(<#value#>, <#fallback#>)",
                   group: .select,
                   priority: 900),
        SQLSnippet(id: "pg.json_extract",
                   title: "jsonb_extract_path_text(...)",
                   detail: "Extract JSON field",
                   insertText: "jsonb_extract_path_text(<#column#>, <#'field'#>)",
                   group: .json,
                   priority: 800)
    ]

    private static let mysqlSnippets: [SQLSnippet] = [
        SQLSnippet(id: "mysql.case",
                   title: "CASE WHEN … END",
                   detail: "Conditional expression",
                   insertText: """
CASE
    WHEN <#condition#> THEN <#result#>
    ELSE <#fallback#>
END
""",
                   group: .select,
                   priority: 1000),
        SQLSnippet(id: "mysql.json_extract",
                   title: "JSON_EXTRACT(column, '$.path')",
                   detail: "Extract JSON field",
                   insertText: "JSON_EXTRACT(<#column#>, '$.<#path#>')",
                   group: .json,
                   priority: 850)
    ]

    private static let sqliteSnippets: [SQLSnippet] = [
        SQLSnippet(id: "sqlite.case",
                   title: "CASE WHEN … END",
                   detail: "Conditional expression",
                   insertText: """
CASE
    WHEN <#condition#> THEN <#result#>
    ELSE <#fallback#>
END
""",
                   group: .select,
                   priority: 950),
        SQLSnippet(id: "sqlite.datetime",
                   title: "datetime('now')",
                   detail: "Current timestamp",
                   insertText: "datetime('now')",
                   group: .select,
                   priority: 800)
    ]

    private static let sqlServerSnippets: [SQLSnippet] = [
        SQLSnippet(id: "mssql.case",
                   title: "CASE WHEN … END",
                   detail: "Conditional expression",
                   insertText: """
CASE
    WHEN <#condition#> THEN <#result#>
    ELSE <#fallback#>
END
""",
                   group: .select,
                   priority: 1000),
        SQLSnippet(id: "mssql.output",
                   title: "OUTPUT inserted.column",
                   detail: "Output clause for DML",
                   insertText: "OUTPUT inserted.<#column#>",
                   group: .modification,
                   priority: 850)
    ]
}
