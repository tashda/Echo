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

        guard let parseResult = await SQLParserBridge.shared.parse(sql: sql, dialect: dialect) else {
            return []
        }

        // Syntax error — only show if the statement looks "finished" (not just typing)
        if !parseResult.success {
            // Don't show syntax errors for very short queries — likely still composing
            if trimmed.count < 10 { return [] }
            // Don't show syntax errors if the SQL ends right where the error is
            if let error = parseResult.error, let offset = error.offset,
               offset >= trimmed.count - 2 {
                return []
            }
            if let error = parseResult.error {
                return [SQLDiagnostic(
                    message: cleanErrorMessage(error.message),
                    severity: .error,
                    kind: .syntaxError,
                    confidence: .high,
                    token: "",
                    offset: error.offset
                )]
            }
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

        return semanticDiagnostics(
            parseResult: parseResult,
            index: index,
            defaultSchema: defaultSchema,
            dialect: dialect
        )
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
