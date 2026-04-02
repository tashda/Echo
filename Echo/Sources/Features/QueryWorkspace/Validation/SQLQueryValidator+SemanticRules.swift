import Foundation
import EchoSense

extension SQLQueryValidator {

    /// Run semantic rules against parsed SQL and metadata.
    /// Returns only high-confidence diagnostics.
    func semanticDiagnostics(
        parseResult: SQLParseResult,
        index: MetadataIndex,
        defaultSchema: String?,
        dialect: EchoSenseDatabaseType
    ) -> [SQLDiagnostic] {
        var diagnostics = [SQLDiagnostic]()

        // Check schemas referenced in the query
        diagnostics.append(contentsOf: checkSchemas(
            tableRefs: parseResult.tableReferences,
            index: index
        ))

        // Check tables referenced in the query
        diagnostics.append(contentsOf: checkTables(
            tableRefs: parseResult.tableReferences,
            index: index,
            defaultSchema: defaultSchema
        ))

        // Check columns — only when all tables in scope are resolved
        diagnostics.append(contentsOf: checkColumns(
            columnRefs: parseResult.columnReferences,
            tableRefs: parseResult.tableReferences,
            index: index,
            defaultSchema: defaultSchema
        ))

        return diagnostics.filter { $0.confidence == .high }
    }

    // MARK: - Schema Check

    /// Flag schema-qualified references where the schema doesn't exist in metadata.
    private func checkSchemas(
        tableRefs: [SQLTableReference],
        index: MetadataIndex
    ) -> [SQLDiagnostic] {
        var diagnostics = [SQLDiagnostic]()
        var checked = Set<String>()

        for ref in tableRefs {
            guard let schema = ref.schema else { continue }
            let key = schema.lowercased()
            guard !checked.contains(key) else { continue }
            checked.insert(key)

            if !index.schemaExists(schema) {
                diagnostics.append(SQLDiagnostic(
                    message: "Unknown schema '\(schema)'",
                    severity: .warning,
                    kind: .unknownSchema,
                    confidence: .high,
                    token: schema
                ))
            }
        }

        return diagnostics
    }

    // MARK: - Table Check

    /// Flag table references that don't exist in metadata.
    private func checkTables(
        tableRefs: [SQLTableReference],
        index: MetadataIndex,
        defaultSchema: String?
    ) -> [SQLDiagnostic] {
        var diagnostics = [SQLDiagnostic]()
        var checked = Set<String>()

        for ref in tableRefs {
            let key: String
            if let schema = ref.schema {
                key = "\(schema.lowercased()).\(ref.table.lowercased())"
            } else {
                key = ref.table.lowercased()
            }
            guard !checked.contains(key) else { continue }
            checked.insert(key)

            if let schema = ref.schema {
                // Schema-qualified: check schema.table
                if index.schemaExists(schema) && !index.tableExists(ref.table, inSchema: schema) {
                    diagnostics.append(SQLDiagnostic(
                        message: "Unknown table '\(ref.table)' in schema '\(schema)'",
                        severity: .error,
                        kind: .unknownTable,
                        confidence: .high,
                        token: ref.table
                    ))
                }
                // If schema doesn't exist, the schema check already flagged it
            } else {
                // Unqualified: check default schema first, then any schema
                let resolved: Bool
                if let defaultSchema {
                    resolved = index.tableExists(ref.table, inSchema: defaultSchema)
                } else {
                    resolved = index.tableExistsAnywhere(ref.table)
                }

                if !resolved && !index.tableExistsAnywhere(ref.table) {
                    diagnostics.append(SQLDiagnostic(
                        message: "Unknown table '\(ref.table)'",
                        severity: .error,
                        kind: .unknownTable,
                        confidence: .high,
                        token: ref.table
                    ))
                }
            }
        }

        return diagnostics
    }

    // MARK: - Column Check

    /// Flag column references that don't exist on any table in scope.
    /// Only flags when ALL tables are resolved (to avoid false positives).
    private func checkColumns(
        columnRefs: [SQLColumnReference],
        tableRefs: [SQLTableReference],
        index: MetadataIndex,
        defaultSchema: String?
    ) -> [SQLDiagnostic] {
        // Skip star references and computed expressions
        let concreteColumns = columnRefs.filter { $0.column != "*" && $0.column != "(.*)" }
        guard !concreteColumns.isEmpty else { return [] }

        // Resolve all tables in scope to their columns
        var resolvedTableColumns = [Set<String>]()
        var allTablesResolved = true

        for tableRef in tableRefs {
            let columns: Set<String>?
            if let schema = tableRef.schema {
                columns = index.columns(forTable: tableRef.table, inSchema: schema)
            } else if let defaultSchema {
                columns = index.columns(forTable: tableRef.table, inSchema: defaultSchema)
                    ?? resolveColumnsFromAnySchema(table: tableRef.table, index: index)
            } else {
                columns = resolveColumnsFromAnySchema(table: tableRef.table, index: index)
            }

            if let columns {
                resolvedTableColumns.append(columns)
            } else {
                allTablesResolved = false
            }
        }

        // If any table in scope is unresolved, downgrade all column diagnostics to medium
        let confidence: SQLDiagnosticConfidence = allTablesResolved ? .high : .medium

        // Build the union of all known columns across all tables in scope
        let allKnownColumns = resolvedTableColumns.reduce(into: Set<String>()) { $0.formUnion($1) }

        var diagnostics = [SQLDiagnostic]()
        var checked = Set<String>()

        for col in concreteColumns {
            let key = col.column.lowercased()
            guard !checked.contains(key) else { continue }
            checked.insert(key)

            // If the column has a table qualifier, skip — the qualifier might be an alias
            // that we can't resolve from tableList alone.
            if col.table != nil {
                continue
            }

            if !allKnownColumns.contains(key) {
                diagnostics.append(SQLDiagnostic(
                    message: "Unknown column '\(col.column)'",
                    severity: .warning,
                    kind: .unknownColumn,
                    confidence: confidence,
                    token: col.column
                ))
            }
        }

        return diagnostics
    }

    /// Try to resolve columns from any schema that contains this table
    private func resolveColumnsFromAnySchema(table: String, index: MetadataIndex) -> Set<String>? {
        let schemas = index.resolveSchemas(forTable: table)
        guard schemas.count == 1, let schema = schemas.first else { return nil }
        return index.columns(forTable: table, inSchema: schema)
    }
}
