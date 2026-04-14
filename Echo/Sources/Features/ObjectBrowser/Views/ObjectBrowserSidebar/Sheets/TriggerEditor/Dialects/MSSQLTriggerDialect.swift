import Foundation
import SQLServerKit

/// MSSQL implementation of the trigger editor dialect.
/// Uses sqlserver-nio typed metadata APIs — no raw SQL in Echo.
struct MSSQLTriggerDialect: TriggerEditorDialect, Sendable {

    var supportsTruncateEvent: Bool { false }
    var supportsWhenCondition: Bool { false }
    var supportsInsteadOfTiming: Bool { true }
    var supportsForEach: Bool { false }
    var supportsFunctionReference: Bool { false }
    var supportsEnableDisable: Bool { true }
    var supportsComments: Bool { true }

    func loadMetadata(session: any DatabaseSession, schema: String, table: String, name: String) async throws -> TriggerEditorMetadata {
        guard let mssql = session as? SQLServerSessionAdapter else {
            throw ViewEditorDialectError.unsupportedSession
        }

        var metadata = TriggerEditorMetadata(
            name: name, functionName: "", timing: .after, forEach: .row,
            onInsert: false, onUpdate: false, onDelete: false, onTruncate: false,
            whenCondition: "", isEnabled: true, description: ""
        )

        guard let details = try await mssql.client.metadata.triggerDetails(schema: schema, table: table, name: name) else {
            return metadata
        }

        metadata.functionName = extractTriggerBody(from: details.definition ?? "")
        metadata.timing = details.isInsteadOf ? .insteadOf : .after
        metadata.isEnabled = !details.isDisabled
        metadata.onInsert = details.isInsertTrigger
        metadata.onUpdate = details.isUpdateTrigger
        metadata.onDelete = details.isDeleteTrigger
        metadata.description = details.comment ?? ""

        return metadata
    }

    func generateSQL(context: TriggerEditorSQLContext) -> String {
        let qualifiedTable = "\(quoteIdentifier(context.schema)).\(quoteIdentifier(context.table))"

        var events: [String] = []
        if context.onInsert { events.append("INSERT") }
        if context.onUpdate { events.append("UPDATE") }
        if context.onDelete { events.append("DELETE") }

        let timing = context.timing == .insteadOf ? "INSTEAD OF" : "AFTER"

        var sql: String
        if context.isEditing {
            sql = "CREATE OR ALTER TRIGGER \(quoteIdentifier(context.name))\nON \(qualifiedTable)\n\(timing) \(events.joined(separator: ", "))\nAS\nBEGIN\n    SET NOCOUNT ON;\n\(context.functionName)\nEND;"
        } else {
            sql = "CREATE TRIGGER \(quoteIdentifier(context.name))\nON \(qualifiedTable)\n\(timing) \(events.joined(separator: ", "))\nAS\nBEGIN\n    SET NOCOUNT ON;\n\(context.functionName)\nEND;"
        }

        if !context.isEnabled && context.isEditing {
            sql += "\n\nGO\n\nDISABLE TRIGGER \(quoteIdentifier(context.name)) ON \(qualifiedTable);"
        }

        if !context.description.isEmpty {
            let escaped = esc(context.description)
            sql += "\n\nGO\n\nEXEC sp_addextendedproperty\n    @name = N'MS_Description',\n    @value = N'\(escaped)',\n    @level0type = N'SCHEMA', @level0name = N'\(esc(context.schema))',\n    @level1type = N'TABLE', @level1name = N'\(esc(context.table))',\n    @level2type = N'TRIGGER', @level2name = N'\(esc(context.name))';"
        }

        return sql
    }

    func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    private func esc(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func extractTriggerBody(from definition: String) -> String {
        guard let beginRange = definition.range(of: "BEGIN", options: .caseInsensitive),
              let endRange = definition.range(of: "END", options: [.caseInsensitive, .backwards]) else {
            return definition
        }
        return String(definition[beginRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
