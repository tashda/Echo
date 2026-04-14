import Foundation
import SQLServerKit

/// MSSQL implementation of the view editor dialect.
/// Uses sqlserver-nio typed metadata APIs — no raw SQL in Echo.
struct MSSQLViewDialect: ViewEditorDialect, Sendable {

    var supportsMaterializedViews: Bool { false }
    var supportsOwnership: Bool { false }
    var supportsComments: Bool { true }
    var supportsCreateOrReplace: Bool { false }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String, isMaterialized: Bool) async throws -> ViewEditorMetadata {
        guard let mssql = session as? SQLServerSessionAdapter else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = ViewEditorMetadata(name: name, owner: "", definition: "", description: "")

        // Load view definition via typed API
        let fullDefinition = try await session.getObjectDefinition(
            objectName: name, schemaName: schema, objectType: .view, database: nil
        )
        metadata.definition = extractViewBody(from: fullDefinition)

        // Load description via typed API
        metadata.description = try await mssql.client.metadata.objectComment(schema: schema, name: name) ?? ""

        return metadata
    }

    func generateSQL(context: ViewEditorSQLContext) -> String {
        let qualifiedName = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"
        var sql = ""

        if context.isEditing {
            sql += "CREATE OR ALTER VIEW \(qualifiedName)\nAS\n\(context.definition);"
        } else {
            sql += "CREATE VIEW \(qualifiedName)\nAS\n\(context.definition);"
        }

        if !context.description.isEmpty {
            let escapedDesc = escapeSQLLiteral(context.description)
            sql += "\n\nGO\n\n"
            if context.isEditing {
                sql += """
                    IF EXISTS (
                        SELECT 1 FROM sys.extended_properties ep
                        JOIN sys.views v ON ep.major_id = v.object_id
                        JOIN sys.schemas s ON v.schema_id = s.schema_id
                        WHERE s.name = N'\(escapeSQLLiteral(context.schema))'
                          AND v.name = N'\(escapeSQLLiteral(context.name))'
                          AND ep.name = N'MS_Description' AND ep.minor_id = 0
                    )
                        EXEC sp_updateextendedproperty
                            @name = N'MS_Description',
                            @value = N'\(escapedDesc)',
                            @level0type = N'SCHEMA', @level0name = N'\(escapeSQLLiteral(context.schema))',
                            @level1type = N'VIEW', @level1name = N'\(escapeSQLLiteral(context.name))';
                    ELSE
                        EXEC sp_addextendedproperty
                            @name = N'MS_Description',
                            @value = N'\(escapedDesc)',
                            @level0type = N'SCHEMA', @level0name = N'\(escapeSQLLiteral(context.schema))',
                            @level1type = N'VIEW', @level1name = N'\(escapeSQLLiteral(context.name))';
                    """
            } else {
                sql += """
                    EXEC sp_addextendedproperty
                        @name = N'MS_Description',
                        @value = N'\(escapedDesc)',
                        @level0type = N'SCHEMA', @level0name = N'\(escapeSQLLiteral(context.schema))',
                        @level1type = N'VIEW', @level1name = N'\(escapeSQLLiteral(context.name))';
                    """
            }
        }

        return sql
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    private func extractViewBody(from fullDefinition: String) -> String {
        let uppercased = fullDefinition.uppercased()
        var searchRange = uppercased.startIndex..<uppercased.endIndex
        while let range = uppercased.range(of: "AS", options: [], range: searchRange) {
            let beforeIndex = range.lowerBound
            let afterIndex = range.upperBound
            let beforeOK = beforeIndex == uppercased.startIndex || uppercased[uppercased.index(before: beforeIndex)].isWhitespace
            let afterOK = afterIndex == uppercased.endIndex || uppercased[afterIndex].isWhitespace || uppercased[afterIndex].isNewline
            if beforeOK && afterOK {
                return String(fullDefinition[afterIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            searchRange = afterIndex..<uppercased.endIndex
        }
        return fullDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func escapeSQLLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
