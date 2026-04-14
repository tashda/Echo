import Foundation
import PostgresKit

/// PostgreSQL implementation of the view editor dialect.
/// Uses postgres-wire typed metadata APIs — no raw SQL in Echo.
struct PostgresViewDialect: ViewEditorDialect, Sendable {

    var supportsMaterializedViews: Bool { true }
    var supportsOwnership: Bool { true }
    var supportsComments: Bool { true }
    var supportsCreateOrReplace: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, name: String, isMaterialized: Bool) async throws -> ViewEditorMetadata {
        guard let pg = session as? PostgresSession else {
            throw ViewEditorDialectError.unsupportedSession
        }

        let details: PostgresViewDetails?
        if isMaterialized {
            details = try await pg.client.metadata.materializedViewDetails(schema: schema, view: name)
        } else {
            details = try await pg.client.metadata.viewDetails(schema: schema, view: name)
        }

        guard let details else {
            return ViewEditorMetadata(name: name, owner: "", definition: "", description: "")
        }

        return ViewEditorMetadata(
            name: details.name,
            owner: details.owner,
            definition: cleanDefinition(details.definition),
            description: details.comment ?? ""
        )
    }

    func generateSQL(context: ViewEditorSQLContext) -> String {
        let qualifiedName = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.name))"
        var sql = ""

        if context.isMaterialized {
            if context.isEditing {
                sql += "DROP MATERIALIZED VIEW IF EXISTS \(qualifiedName);\n\n"
                sql += "CREATE MATERIALIZED VIEW \(qualifiedName) AS\n\(context.definition);"
            } else {
                sql += "CREATE MATERIALIZED VIEW \(qualifiedName) AS\n\(context.definition);"
            }
        } else {
            sql += "CREATE OR REPLACE VIEW \(qualifiedName) AS\n\(context.definition);"
        }

        if !context.owner.isEmpty && context.isEditing {
            let keyword = context.isMaterialized ? "MATERIALIZED VIEW" : "VIEW"
            sql += "\n\nALTER \(keyword) \(qualifiedName) OWNER TO \(quoteIdentifier(context.owner));"
        }

        if !context.description.isEmpty {
            let keyword = context.isMaterialized ? "MATERIALIZED VIEW" : "VIEW"
            let escapedComment = context.description.replacingOccurrences(of: "'", with: "''")
            sql += "\n\nCOMMENT ON \(keyword) \(qualifiedName) IS '\(escapedComment)';"
        }

        return sql
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func cleanDefinition(_ raw: String) -> String {
        var definition = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if definition.hasSuffix(";") {
            definition = String(definition.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return definition
    }
}

enum ViewEditorDialectError: LocalizedError {
    case unsupportedSession

    var errorDescription: String? {
        switch self {
        case .unsupportedSession:
            "The current connection does not support this editor."
        }
    }
}
