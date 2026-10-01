import Foundation
import EchoSense

/// Severity of a validation diagnostic
enum SQLDiagnosticSeverity: Sendable {
    case error
    case warning
}

/// What kind of issue was found
enum SQLDiagnosticKind: Sendable {
    case syntaxError
    case unknownTable
    case unknownSchema
    case unknownColumn
}

/// How confident the validator is that the diagnostic is correct.
/// Only `.high` confidence diagnostics are shown by default.
enum SQLDiagnosticConfidence: Sendable {
    /// Confident: metadata is fully loaded and the reference is definitively wrong
    case high
    /// Uncertain: some tables in scope are unresolved, or metadata may be incomplete
    case medium
}

/// A single validation diagnostic for a SQL query
struct SQLDiagnostic: Sendable, Equatable {
    let message: String
    let severity: SQLDiagnosticSeverity
    let kind: SQLDiagnosticKind
    let confidence: SQLDiagnosticConfidence
    /// The problematic token text (empty for syntax errors)
    let token: String
    /// Character offset in the SQL text (for syntax errors from the parser)
    let offset: Int?

    init(message: String, severity: SQLDiagnosticSeverity, kind: SQLDiagnosticKind,
         confidence: SQLDiagnosticConfidence, token: String, offset: Int? = nil) {
        self.message = message
        self.severity = severity
        self.kind = kind
        self.confidence = confidence
        self.token = token
        self.offset = offset
    }

    static func == (lhs: SQLDiagnostic, rhs: SQLDiagnostic) -> Bool {
        lhs.message == rhs.message && lhs.token == rhs.token && lhs.kind == rhs.kind
    }
}

/// Validates SQL queries against database metadata.
///
/// Uses `SQLParserBridge` for syntax parsing and `EchoSenseDatabaseStructure` for semantic checks.
/// Only returns high-confidence diagnostics to avoid false positives.
struct SQLQueryValidator {
    private struct ValidationStatement {
        let sql: String
        let utf16Offset: Int
    }

    /// SQL keywords that indicate the user is still typing — don't validate incomplete statements
    private static let trailingKeywords: Set<String> = [
        "from", "join", "inner", "left", "right", "outer", "cross", "full",
        "where", "and", "or", "on", "select", "insert", "into", "update",
        "set", "delete", "values", "order", "group", "having", "by",
        "as", "in", "not", "like", "between", "exists", "case", "when",
        "then", "else", "end", "union", "except", "intersect", "with"
    ]

    func validate(
        sql: String,
        structure: EchoSenseDatabaseStructure?,
        selectedDatabase: String?,
        defaultSchema: String?,
        dialect: EchoSenseDatabaseType
    ) async -> [SQLDiagnostic] {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Don't validate if the user is mid-statement (ends with a keyword + optional whitespace)
        if isIncompleteStatement(trimmed) {
            return []
        }

        let statements = validationStatements(in: sql)
        var parsedStatements: [(SQLParseResult, Int)] = []

        for statement in statements {
            let statementSQL = statement.sql.trimmingCharacters(in: .whitespacesAndNewlines)
            if isIncompleteStatement(statementSQL) {
                continue
            }

            let parserSQL = parserSQL(for: statement.sql, dialect: dialect)
            guard let parseResult = await SQLParserBridge.shared.parse(sql: parserSQL, dialect: dialect) else {
                continue
            }

            // Syntax error — only show if the statement looks "finished" (not just typing)
            if !parseResult.success {
                // Don't show syntax errors for very short queries — likely still composing
                if statementSQL.count < 10 { continue }
                // Don't show syntax errors if the SQL ends right where the error is
                if let error = parseResult.error, let offset = error.offset,
                   offset >= statementSQL.utf16.count - 2 {
                    continue
                }
                if let error = parseResult.error {
                    return [SQLDiagnostic(
                        message: cleanErrorMessage(error.message),
                        severity: .error,
                        kind: .syntaxError,
                        confidence: .high,
                        token: "",
                        offset: error.offset.map { statement.utf16Offset + $0 }
                    )]
                }
                continue
            }

            parsedStatements.append((parseResult, statement.utf16Offset))
        }

        guard !parsedStatements.isEmpty else {
            return []
        }

        // No metadata — skip all semantic checks
        guard let structure else {
            return []
        }

        // Build lookup index across ALL databases (cross-database queries are supported)
        let index = MetadataIndex(structure: structure, selectedDatabase: selectedDatabase)

        // If metadata has no schemas or no tables loaded, skip — metadata isn't ready
        guard index.hasSubstantialMetadata else {
            return []
        }

        return parsedStatements.flatMap { parseResult, _ in
            semanticDiagnostics(
                parseResult: parseResult,
                index: index,
                defaultSchema: defaultSchema,
                dialect: dialect
            )
        }
    }

    /// Check if the SQL appears to be an incomplete statement the user is still typing
    private func isIncompleteStatement(_ sql: String) -> Bool {
        // Get the last meaningful token
        let words = sql.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard let lastWord = words.last else { return true }

        // If the last token is a SQL keyword, user is still composing
        return Self.trailingKeywords.contains(lastWord)
    }

    private func cleanErrorMessage(_ message: String) -> String {
        if let firstLine = message.components(separatedBy: "\n").first,
           firstLine.count < 200 {
            return firstLine
        }
        return String(message.prefix(200))
    }

    private func validationStatements(in sql: String) -> [ValidationStatement] {
        let semicolonStatements = TSQLStatementSplitter.split(sql)
        if semicolonStatements.count > 1 {
            return semicolonStatements.map {
                ValidationStatement(
                    sql: $0.text,
                    utf16Offset: sql.utf16.distance(from: sql.utf16.startIndex, to: $0.range.lowerBound.samePosition(in: sql.utf16) ?? sql.utf16.startIndex)
                )
            }
        }

        return splitImplicitLineStatements(in: sql)
    }

    private func splitImplicitLineStatements(in sql: String) -> [ValidationStatement] {
        var statements: [ValidationStatement] = []
        var currentStart = sql.startIndex
        var currentUTF16Offset = 0
        var index = sql.startIndex

        while index < sql.endIndex {
            if sql[index] == "\n" {
                let nextLineStart = sql.index(after: index)
                let nextLineOffset = sql.utf16.distance(from: sql.utf16.startIndex, to: nextLineStart.samePosition(in: sql.utf16) ?? sql.utf16.endIndex)

                if nextLineStart < sql.endIndex,
                   startsImplicitStatement(at: nextLineStart, in: sql),
                   hasStatementText(sql[currentStart..<index]) {
                    let text = String(sql[currentStart..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        statements.append(ValidationStatement(sql: text, utf16Offset: currentUTF16Offset))
                    }
                    currentStart = nextLineStart
                    currentUTF16Offset = nextLineOffset
                }
            }
            index = sql.index(after: index)
        }

        let remaining = String(sql[currentStart..<sql.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            statements.append(ValidationStatement(sql: remaining, utf16Offset: currentUTF16Offset))
        }

        return statements.isEmpty ? [ValidationStatement(sql: sql, utf16Offset: 0)] : statements
    }

    private func startsImplicitStatement(at position: String.Index, in sql: String) -> Bool {
        var index = position
        while index < sql.endIndex, sql[index] == " " || sql[index] == "\t" {
            index = sql.index(after: index)
        }

        let statementStarters = ["select", "with", "insert", "update", "delete", "merge", "create", "alter", "drop", "truncate", "declare", "set", "exec", "execute"]
        return statementStarters.contains { keyword in
            matchesKeyword(keyword, in: sql, at: index)
        }
    }

    private func hasStatementText(_ text: Substring) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func matchesKeyword(_ keyword: String, in sql: String, at position: String.Index) -> Bool {
        var keywordIndex = keyword.startIndex
        var sqlIndex = position

        while keywordIndex < keyword.endIndex, sqlIndex < sql.endIndex {
            guard keyword[keywordIndex].lowercased() == sql[sqlIndex].lowercased() else { return false }
            keywordIndex = keyword.index(after: keywordIndex)
            sqlIndex = sql.index(after: sqlIndex)
        }

        guard keywordIndex == keyword.endIndex else { return false }
        if sqlIndex < sql.endIndex {
            let next = sql[sqlIndex]
            if next.isLetter || next.isNumber || next == "_" { return false }
        }
        return true
    }

    private func parserSQL(for sql: String, dialect: EchoSenseDatabaseType) -> String {
        guard dialect == .microsoftSQL else { return sql }
        return replacingTSQLVariablesForParser(in: sql)
    }

    private func replacingTSQLVariablesForParser(in sql: String) -> String {
        var output = String()
        output.reserveCapacity(sql.count)

        var index = sql.startIndex
        while index < sql.endIndex {
            if sql[index] == "'" {
                let end = appendStringLiteral(from: index, in: sql, to: &output)
                index = end
                continue
            }

            if sql[index] == "-" {
                let next = sql.index(after: index)
                if next < sql.endIndex, sql[next] == "-" {
                    let end = appendLineComment(from: index, in: sql, to: &output)
                    index = end
                    continue
                }
            }

            if sql[index] == "/" {
                let next = sql.index(after: index)
                if next < sql.endIndex, sql[next] == "*" {
                    let end = appendBlockComment(from: index, in: sql, to: &output)
                    index = end
                    continue
                }
            }

            if sql[index] == "@" {
                let variableEnd = tsqlVariableEnd(from: index, in: sql)
                if variableEnd > sql.index(after: index) {
                    output.append("0")
                    let remainingLength = sql.distance(from: sql.index(after: index), to: variableEnd)
                    output.append(String(repeating: " ", count: remainingLength))
                    index = variableEnd
                    continue
                }
            }

            output.append(sql[index])
            index = sql.index(after: index)
        }

        return output
    }

    private func appendStringLiteral(from start: String.Index, in sql: String, to output: inout String) -> String.Index {
        var index = start
        output.append(sql[index])
        index = sql.index(after: index)

        while index < sql.endIndex {
            output.append(sql[index])
            if sql[index] == "'" {
                let next = sql.index(after: index)
                if next < sql.endIndex, sql[next] == "'" {
                    output.append(sql[next])
                    index = sql.index(after: next)
                    continue
                }
                return next
            }
            index = sql.index(after: index)
        }

        return index
    }

    private func appendLineComment(from start: String.Index, in sql: String, to output: inout String) -> String.Index {
        var index = start
        while index < sql.endIndex {
            output.append(sql[index])
            let next = sql.index(after: index)
            if sql[index] == "\n" {
                return next
            }
            index = next
        }
        return index
    }

    private func appendBlockComment(from start: String.Index, in sql: String, to output: inout String) -> String.Index {
        var index = start
        while index < sql.endIndex {
            output.append(sql[index])
            let next = sql.index(after: index)
            if sql[index] == "*", next < sql.endIndex, sql[next] == "/" {
                output.append(sql[next])
                return sql.index(after: next)
            }
            index = next
        }
        return index
    }

    private func tsqlVariableEnd(from start: String.Index, in sql: String) -> String.Index {
        var index = sql.index(after: start)
        if index < sql.endIndex, sql[index] == "@" {
            index = sql.index(after: index)
        }

        let nameStart = index
        while index < sql.endIndex {
            let character = sql[index]
            if character.isLetter || character.isNumber || character == "_" {
                index = sql.index(after: index)
            } else {
                break
            }
        }

        return index > nameStart ? index : start
    }
}

// MARK: - Metadata Index

struct MetadataIndex {
    /// All known schema names across all databases (lowercased)
    let schemas: Set<String>
    /// All known database names (lowercased)
    let databases: Set<String>
    /// schema (lowercased) → set of table/view names (lowercased)
    let tablesBySchema: [String: Set<String>]
    /// "schema.table" (lowercased) → set of column names (lowercased)
    let columnsByTable: [String: Set<String>]
    /// All table names across all schemas and databases (lowercased)
    let allTables: Set<String>
    /// table name (lowercased) → [schema names]
    let schemasByTable: [String: [String]]

    /// True if we have at least one schema with at least one table — metadata is actually loaded
    var hasSubstantialMetadata: Bool {
        !schemas.isEmpty && !allTables.isEmpty
    }

    /// Build an index across ALL databases in the structure.
    /// Cross-database queries are a key feature — we must recognize tables from any database.
    init(structure: EchoSenseDatabaseStructure, selectedDatabase: String?) {
        var schemas = Set<String>()
        var databases = Set<String>()
        var tablesBySchema = [String: Set<String>]()
        var columnsByTable = [String: Set<String>]()
        var allTables = Set<String>()
        var schemasByTable = [String: [String]]()

        for db in structure.databases {
            databases.insert(db.name.lowercased())

            for schema in db.schemas {
                let schemaKey = schema.name.lowercased()
                schemas.insert(schemaKey)

                var tables = Set<String>()
                for object in schema.objects where object.type == .table || object.type == .view || object.type == .materializedView {
                    let tableKey = object.name.lowercased()
                    tables.insert(tableKey)
                    allTables.insert(tableKey)
                    schemasByTable[tableKey, default: []].append(schemaKey)

                    let qualifiedKey = "\(schemaKey).\(tableKey)"
                    let columns = Set(object.columns.map { $0.name.lowercased() })
                    columnsByTable[qualifiedKey] = columns
                }
                // Merge tables into existing schema entry (same schema name can appear in multiple databases)
                tablesBySchema[schemaKey, default: []].formUnion(tables)
            }
        }

        self.schemas = schemas
        self.databases = databases
        self.tablesBySchema = tablesBySchema
        self.columnsByTable = columnsByTable
        self.allTables = allTables
        self.schemasByTable = schemasByTable
    }

    func schemaExists(_ name: String) -> Bool {
        schemas.contains(name.lowercased())
    }

    func databaseExists(_ name: String) -> Bool {
        databases.contains(name.lowercased())
    }

    func tableExists(_ table: String, inSchema schema: String) -> Bool {
        tablesBySchema[schema.lowercased()]?.contains(table.lowercased()) ?? false
    }

    func tableExistsAnywhere(_ table: String) -> Bool {
        allTables.contains(table.lowercased())
    }

    func columns(forTable table: String, inSchema schema: String) -> Set<String>? {
        columnsByTable["\(schema.lowercased()).\(table.lowercased())"]
    }

    func resolveSchemas(forTable table: String) -> [String] {
        schemasByTable[table.lowercased()] ?? []
    }
}
